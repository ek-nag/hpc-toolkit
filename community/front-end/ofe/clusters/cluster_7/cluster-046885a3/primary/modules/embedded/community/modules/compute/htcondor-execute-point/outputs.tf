/**
 * Copyright 2022 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

output "autoscaler_runner" {
  value       = local.autoscaler_runner
  description = "Toolkit runner to configure the HTCondor autoscaler"
}

output "mig_id" {
  value       = module.mig.instance_group_manager.name
  description = "ID of the managed instance group containing the execute points"
}
