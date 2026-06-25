import configparser
import time
import influxdb_client
import pandas as pd

from .DetectionExecutor import DetectionExecutor

from ..utils import Util

from influxdb_client.client.write_api import SYNCHRONOUS

config = configparser.ConfigParser()
config.read('/tmp/src/configuration/config.ini')

log = Util.get_logger()

class InfluxDBManager:

    """
    Retrieves the latest data from InfluxDB for the specified measurement.

    This method connects to the configured InfluxDB instance, queries the latest data within the last 48 hours,
    and returns the results as a pandas DataFrame. If an error occurs during the query, an empty DataFrame is returned.

    Parameters:
    measurement (str): The name of the measurement to query from InfluxDB.

    Returns:
    pd.DataFrame: A pandas DataFrame containing the queried data. An empty DataFrame is returned if an error occurs.
    """
    def getLatestData(self, measurement) -> pd.DataFrame:
        log.debug('InfluxDBManager.getLatestData :: getLatestData called')
        
        client = influxdb_client.InfluxDBClient(url = config.get('APP', 'INFLUX_URL'),
                                     token=config.get('APP', 'INFLUX_TOKEN'),
                                     org=config.get('APP', 'INFLUX_ORG'))
        query_api = client.query_api()

        INFLUXDB_BUCKET = config.get('APP', 'INFLUX_BUCKET')
        flux_query = f'''
        from(bucket: "{INFLUXDB_BUCKET}")
            |> range(start: -48h)  // Adjust the range as needed
            |> filter(fn: (r) => r["_measurement"] == "{measurement}")
            |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
        '''

        try:
            df = query_api.query_data_frame(flux_query)
            return df
        except Exception as e:
            log.error(f"An error occurred while querying InfluxDB: {e}")
            return pd.DataFrame()
        finally:
            client.close()

    """
    Continuously queries InfluxDB for the latest data based on the configured measurement name.
        
    This method retrieves the latest data from InfluxDB for a specified measurement, processes it,
    and checks if there is sufficient data to perform anomaly detection. If sufficient data is found,
    it initiates the anomaly detection process using the DetectionExecutor class. The method runs 
    indefinitely with a sleep interval between each query defined by KPI_FETCH_INTERVAL in the configuration.
    """
    def query(self):
        log.debug('InfluxDBManager.query :: query called')
        while True:
            measurement = config.get('APP', 'MEASUREMENT_NAME')
            log.debug('measurement name [{}]'.format(measurement))
            latestDataDF = self.getLatestData(measurement)

            if not latestDataDF.empty:
                log.info(f"Latest data from measurement: '{measurement}'")
                Util.log_dataframe(latestDataDF)

                latestDataDF  = latestDataDF.drop(['table', '_start', '_stop', '_time', '_measurement', 'result'], axis=1)

                if len(latestDataDF.index) > int(config.get('APP', 'DETECTION_COUNT')):
                    log.info(f"Greater than 1 day suffiecient data is present to detect anamoly for cell  '{latestDataDF.loc[0, 'Short name']}'")
                    log.debug('latestDataDF.shape: [{}]'.format(latestDataDF.shape))
                    detectionExecutor = DetectionExecutor()
                    detectionExecutor.execute(latestDataDF.drop(['Short name'], axis=1))  
                else:
                    log.info(f"No suffiecient data to detect anamoly for cell  '{latestDataDF.loc[0, 'Short name']}'")       
            else:
                log.info(f"No data available in measurement '{measurement}'.")
            time.sleep(int(config.get('APP', 'KPI_FETCH_INTERVAL')))