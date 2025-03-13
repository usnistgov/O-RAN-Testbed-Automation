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
import time
import pandas as pd
from influxdb_client import InfluxDBClient
from influxdb_client.client.write_api import SYNCHRONOUS
from configparser import ConfigParser
from mdclogpy import Logger

logger = Logger(name=__name__)

class DATABASE(object):
    r"""DATABASE takes an input as database name. It creates a client connection
      to influxDB and It reads/ writes UE data for a given dabtabase and a measurement.

    Parameters
    ----------
    host: str (default='r4-influxdb-influxdb2.ricplt.svc.cluster.local')
        hostname to connect to InfluxDB
    port: int (default='8086')
        port to connect to InfluxDB
    token: str (default='')
        token to connect

    Attributes
    ----------
    client: influxDB client
        DataFrameClient api to connect influxDB
    data: DataFrame
        fetched data from database
    """

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
        self.data = None
        self.host = host
        self.port = port
        self.token = token
        self.org = org
        self.bucket = bucket
        self.path = path
        self.ssl = ssl
        self.dbname = dbname
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

    def read_data(self, train=False, valid=False, limit=False):
        """Read data method for a given measurement and limit

        Parameters
        ----------
        meas: str (default='ueMeasReport')
        limit:int (defualt=False)
        """
        # self.data = None
        # query = 'select * from ' + self.meas
        # if not train and not valid and not limit:
        #     query += ' where time>now()-1600ms'
        # elif train:
        #     query += ' where time<now()-5m and time>now()-75m'
        # elif valid:
        #     query += ' where time>now()-5m'
        # elif limit:
        #     query += ' where time>now()-1m limit '+str(limit)
        # result = self.query(query)
        # if result and len(result[self.meas]) != 0:
        #     self.data = result[self.meas]
        self.data = None
        base_query = f'from(bucket: "{self.bucket}")'
        if train:
            query = f'{base_query} |> range(start: -75m, stop: -5m) |> filter(fn: (r) => r._measurement == "{self.meas}")'
        elif valid:
            query = f'{base_query} |> range(start: -5m) |> filter(fn: (r) => r._measurement == "{self.meas}")'
        else:
            query = f'{base_query} |> range(start: -1600ms) |> filter(fn: (r) => r._measurement == "{self.meas}")'
        if limit:
            query += f" |> limit(n: {limit})"
        result = self.query(query)
        if result and not result.is_empty():
            self.data = result

    def write_anomaly(self, df, meas="AD"):
        """Write data method for a given measurement

        Parameters
        ----------
        meas: str (default='AD')
        """
        try:
            write_api = self.client.write_api()
            write_api.write(bucket=self.bucket, org=self.org, record=df)
        except Exception as e:
            logger.error("Failed to send metrics to influxdb")
            print(e)

    def query(self, query):
        try:
            query_api = self.client.query_api()
            result = query_api.query(query)
        except Exception as e:
            logger.error("Failed to connect to influxdb: {}".format(e))
            result = False
        return result

    def config(self):
        cfg = ConfigParser()
        cfg.read("src/ad_config.ini")
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
                self.meas = cfg.get(section, "measurement")

            if section == "features":
                self.thpt = cfg.get(section, "thpt")
                self.rsrp = cfg.get(section, "rsrp")
                self.rsrq = cfg.get(section, "rsrq")
                self.rssinr = cfg.get(section, "rssinr")
                self.prb = cfg.get(section, "prb_usage")
                self.ue = cfg.get(section, "ue")
                self.anomaly = cfg.get(section, "anomaly")
                self.a1_param = cfg.get(section, "a1_param")

class DUMMY(DATABASE):

    def __init__(self):
        super().__init__()
        self.ue_data = pd.read_csv("src/ue.csv")

    def connect(self):
        return True

    def read_data(self, train=False, valid=False, limit=100000):
        if not train:
            self.data = self.ue_data.head(limit)
        else:
            self.data = self.ue_data.head(limit).drop(self.anomaly, axis=1)

    def write_anomaly(self, df, meas_name="AD"):
        pass

    def query(self, query=None):
        return {"UEReports": self.ue_data.head(1)}
