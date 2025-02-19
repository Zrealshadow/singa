#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#!/bin/bash

# Check for proper number of command line args
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <data_path> <db_name>"
    exit 1
fi

# Configurations
DATA_PATH="$1"
DB_NAME="$2"

# Connection details
HOST="localhost"
PORT="28814"
USERNAME="postgres"
DBNAME="pg_extension"

# Create the database
echo "Creating database..."
createdb -h $HOST -p $PORT -U $USERNAME $DBNAME

# Define datasets to process
datasets=("train" "valid" "test")

# Loop over each dataset
for dataset in "${datasets[@]}"; do
    rm "${DATA_PATH}/${dataset}.csv"

    # 1. Identify the number of columns
    num_columns=$(awk 'NF > max { max = NF } END { print max }' "${DATA_PATH}/${dataset}.libsvm")

    # 2. Create the table dynamically
    create_table_cmd="CREATE TABLE ${DB_NAME}_${dataset} (id SERIAL PRIMARY KEY, label INTEGER"

    for (( i=2; i<=$num_columns; i++ )); do
        create_table_cmd+=", col$(($i-1)) TEXT"
    done
    create_table_cmd+=");"

    echo "Creating ${dataset} table..."
    echo $create_table_cmd | psql -h $HOST -p $PORT -U $USERNAME -d $DBNAME

    # 3. Transform the libsvm format to CSV
    echo "Transforming ${dataset} to CSV format..."

    awk '{
        for (i = 1; i <= NF; i++) {
            printf "%s", $i;  # print each field as-is
            if (i < NF) {
                printf " ";  # if its not the last field, print a space
            }
        }
        printf "\n";  # end of line
    }' "${DATA_PATH}/${dataset}.libsvm" > "${DATA_PATH}/${dataset}.csv"

    # 4. Import into PostgreSQL
    columns="label"
    for (( i=2; i<=$num_columns; i++ )); do
        columns+=", col$(($i-1))"
    done

    echo "Loading ${dataset} into PostgreSQL..."
    psql -h $HOST -p $PORT -U $USERNAME -d $DBNAME -c "\COPY ${DB_NAME}_${dataset}($columns) FROM '${DATA_PATH}/${dataset}.csv' DELIMITER ' '"
done

echo "Data load complete."
