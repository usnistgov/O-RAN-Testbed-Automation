# ==================================================================================
#       Copyright (c) 2020 HCL Intellectual Property.
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

from setuptools import setup, find_packages

setup(
    name="ad",
    version="1.0.1",
    packages=find_packages(exclude=["tests.*", "tests"]),
    description="Anomaly Detection xApp that integrates with Traffic Steering",
    url="https://gerrit.o-ran-sc.org/r/admin/repos/ric-app/ad",
    install_requires=["ricxappframe==3.2.2", "pandas>=1.1.3", "joblib>=0.3.2", "Scikit-learn>=0.18", "mdclogpy<=1.1.1", "schedule>=0.0.0", "influxdb"],
    entry_points={"console_scripts": ["run-src.py=src.main:start"]},  # adds a magical entrypoint for Docker
    license="Apache 2.0",
    data_files=[("", ["LICENSE.txt"])],
)
