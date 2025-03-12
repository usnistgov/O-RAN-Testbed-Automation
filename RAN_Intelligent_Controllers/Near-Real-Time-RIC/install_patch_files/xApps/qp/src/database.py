# ==================================================================================
#       Copyright (c) 2020 AT&T Intellectual Property.
#       Copyright (c) 2020 HCL Technologies Limited.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#          http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
# ==================================================================================
from influxdb_client import InfluxDBClient
from influxdb_client.client.write_api import SYNCHRONOUS
from configparser import ConfigParser
from mdclogpy import Logger
from src.exceptions import NoDataError
import pandas as pd
import time

logger = Logger(name=__name__)


class DATABASE(object):

    def __init__(
        self,
        dbname="Timeseries",
        token="",
        org="influxdata",
        bucket="kpimon",
        host="r4-influxdb-influxdb2.ricplt",
        port="80",
        path="",
        ssl=False,
    ):
        self.host = host
        self.port = port
        self.token = token
        self.org = org
        self.bucket = bucket
        self.path = path
        self.ssl = ssl
        self.dbname = dbname
        self.data = None
        self.client = None
        self.write_api = None
        self.config()

    def connect(self):
        if self.client is not None:
            self.client.close()

        self.client = InfluxDBClient(
            url=f"http://{self.host}:{self.port}", token=self.token, org=self.org
        )
        self.write_api = self.client.write_api(write_options=SYNCHRONOUS)
        try:
            query_api = self.client.query_api()
            query_api.query(
                'from(bucket: "{}") |> range(start: -1m)'.format(self.bucket)
            )
            logger.info("Connected to Influx Database")
            return True
        except Exception as e:
            logger.error(
                f"Failed to establish a new connection with InfluxDB. Please check your URL/hostname: {self.host}. Error: {e}"
            )
            time.sleep(120)

    def read_data(self, meas="ueMeasReport", limit=10000, cellid=False, ueid=False):

        if cellid:
            meas = self.cellmeas
            param = self.cid
            Id = cellid

        if ueid:
            meas = self.uemeas
            param = self.ue
            limit = 1
            Id = ueid

        base_query = f'from(bucket: "{self.bucket}")'
        query = f'{base_query} |> range(start: -1600ms) |> filter(fn: (r) => r._measurement == "{meas}")'
        if limit:
            query += f" |> limit(n: {limit})"
        result = self.client.query_api().query(query)
        if result and not result.is_empty():
            self.data = result

    def query(self, query):
        try:
            query_api = self.client.query_api()
            result = query_api.query(query)
            if len(result) == 0:
                raise NoDataError
            else:
                self.data = result[meas]

        except NoDataError:
            self.data = None
            if Id:
                logger.error("Data not found for " + Id + " in measurement: " + meas)
            else:
                logger.error("Data not found for " + meas)

        except Exception as e:
            logger.error("Failed to connect to influxdb: {}".format(e))
            result = False

    def cells(self, meas="CellReports", limit=100):
        meas = self.cellmeas
        query = """select * from {}""".format(meas)
        query += " ORDER BY DESC LIMIT {}".format(limit)
        self.query(query, meas)
        if self.data is not None:
            return self.data[self.cid].unique()

    def write_prediction(self, df, meas_name="QP"):
        try:
            self.write_api.write(bucket=self.bucket, org=self.org, record=df)
        except Exception as e:
            logger.error("Failed to send metrics to influxdb")
            print(e)

    def config(self):
        cfg = ConfigParser()
        cfg.read("src/qp_config.ini")
        for section in cfg.sections():
            if section == "influxdb":
                self.host = cfg.get(section, "host")
                self.port = cfg.get(section, "port")
                self.token = cfg.get(section, "token")
                self.org = cfg.get(section, "org")
                self.bucket = cfg.get(section, "bucket")
                self.path = cfg.get(section, "path")
                self.ssl = cfg.get(section, "ssl")
                self.dbname = cfg.get(section, "database")

            if section == "features":
                self.thptparam = [
                    cfg.get(section, "thptUL"),
                    cfg.get(section, "thptDL"),
                ]
                self.nbcells = cfg.get(section, "nbcells")
                self.servcell = cfg.get(section, "servcell")
                self.ue = cfg.get(section, "ue")
                self.cid = cfg.get(section, "cid")


class DUMMY(DATABASE):

    def __init__(self):
        super().__init__()
        self.ue_data = pd.DataFrame(
            [
                [
                    1002,
                    "c2/B13",
                    8,
                    69,
                    65,
                    113,
                    0.1,
                    0.1,
                    "Car-1",
                    -882,
                    -959,
                    pd.to_datetime("2021-05-12T07:43:51.652"),
                ]
            ],
            columns=[
                "du-id",
                "RF.serving.Id",
                "prb_usage",
                "rsrp",
                "rsrq",
                "rssinr",
                "throughput",
                "targetTput",
                "ue-id",
                "x",
                "y",
                "measTimeStampRf",
            ],
        )

        self.cell = pd.read_csv("src/cells.csv")

    def read_data(self, meas="ueMeasReport", limit=100000, cellid=False, ueid=False):
        if ueid:
            self.data = self.ue_data.head(limit)
        if cellid:
            self.data = self.cell.head(limit)

    def cells(self):
        return self.cell[self.cid].unique()

    def write_prediction(self, df, meas_name="QP"):
        pass

    def query(self, query=None):
        return {"UEReports": self.ue_data.head(1)}
