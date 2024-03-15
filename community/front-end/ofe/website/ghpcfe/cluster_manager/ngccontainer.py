# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""NGC container operations"""

#from . import utils
#import sys
import requests

url = 'https://api.ngc.nvidia.com/v2/models/'
response = requests.get(url)

def get_model_list():
    """
    Fetches model names from the NVIDIA NGC API and returns them in a structured list.
    
    Returns:
        list of str: A list containing the names of the models.
    """
    url = 'https://api.ngc.nvidia.com/v2/models/'
    model_names = []
    
    try:
        # Perform a GET request to fetch the data
        response = requests.get(url)
        response.raise_for_status()  # Raises an HTTPError if the response status code is 4XX/5XX

        # Parse the JSON content of the response
        data = response.json()
        
        # Extract the name of each model
        model_names = [model['name'] for model in data.get('models', [])]
        
    except requests.RequestException as e:
        print(f"An error occurred while fetching model names: {e}")
    
    return model_names


def get_model_info(names):
    models = [model for model in data['models'] if model['name'] in names]
    return (
        {
            "name": model['name'],
            "orgName": model['orgName'],
            "shortDescription": model['shortDescription'],
            "teamName": model['teamName'],
            "application": model['application'],
            "latestVersionIdStr": model['latestVersionIdStr'],
            "precision": model['precision'],
            "framework": model['framework'],
            "createdDate": model['createdDate'],
            "displayName": model['displayName'],
            "modelFormat": model['modelFormat'],
            "updatedDate": model['updatedDate'],
        }
        for model in models
    )