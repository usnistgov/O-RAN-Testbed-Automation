# ==================================================================================
#  Copyright (c) 2020 HCL Technologies Limited.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
# ==================================================================================

"""
This Module is temporary for pushing data into influxdb before dpeloyment of QP xApp. It will depreciated in future, when data will be coming through KPIMON
"""

import datetime
import time
import pandas as pd
from src.database import DATABASE
from configparser import ConfigParser

class INSERTDATA(DATABASE):

    def __init__(self):
        super().__init__()
        self.connect()

    def createdb(self, bucket_name):
        bucket_api = self.client.buckets_api()
        if not bucket_api.find_bucket_by_name(bucket_name):
            print(f"Create bucket: {bucket_name}")
            bucket_api.create_bucket(bucket_name=bucket_name, org=self.org)

    def dropdb(self, bucket_name):
        bucket_api = self.client.buckets_api()
        bucket = bucket_api.find_bucket_by_name(bucket_name)
        if bucket:
            print(f"DROP bucket: {bucket_name}")
            bucket_api.delete_bucket(bucket)

    def dropmeas(self, measname):
        print("DROP MEASUREMENT: " + measname)
        self.client.query("DROP MEASUREMENT " + measname)

    def assign_timestamp(self, df):
        steps = df["measTimeStampRf"].unique()
        for timestamp in steps:
            d = df[df["measTimeStampRf"] == timestamp]
            d.index = pd.date_range(
                start=datetime.datetime.now(), freq="1ms", periods=len(d)
            )
            self.write_api.write(
                bucket=self.bucket, record=d, data_frame_measurement_name=self.cellmeas
            )
            time.sleep(0.4)

def populatedb():
    # inintiate connection and create database UEDATA
    db = INSERTDATA()
    df = pd.read_csv("src/cells.csv")
    print("Writinig data into influxDB")
    while True:
        db.assign_timestamp(df)

if __name__ == "__main__":
    populatedb()
