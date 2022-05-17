# Intel Solutions for the HPC Toolkit

## Intel-Optimized Slurm Cluster

This document is adapted from a [Cloud Shell tutorial][tutorial] developed to
demonstrate Intel Select Solutions within the Toolkit. It expands upon that
tutorial by building custom images that save provisioning time and improve
reliability when scaling up compute nodes.

The Google Cloud [HPC VM Image][hpcvmimage] has a built-in feature enabling it
to install a Google Cloud-tested release of Intel compilers and libraries that
are known to achieve optimal performance on Google Cloud.

[tutorial]: ../../../docs/tutorials/intel-select/intel-select.md
[hpcvmimage]: https://cloud.google.com/compute/docs/instances/create-hpc-vm

## Provisioning the Intel-optimized Slurm cluster

Identify a project to work in and substitute its unique id wherever you see
`<<PROJECT_ID>>` in the instructions below.

## Initial Setup

Before provisioning any infrastructure in this project you should follow the
Toolkit guidance to enable [APIs][apis] and establish minimum resource
[quotas][quotas]. In particular, the following APIs should be enabled

* file.googleapis.com (Cloud Filestore)
* compute.googleapis.com (Google Compute Engine)

[apis]: ../../../README.md#enable-gcp-apis
[quotas]: ../../../README.md#gcp-quotas

And the following available quota is required in the region used by the cluster:

* Filestore: 2560GB
* C2 CPUs: 6000 (fully-scaled "compute" partition)
  * This quota is not necessary at initial deployment, but will be required to
    successfully scale the partition to its maximum size
* C2 CPUs: 4 (login node)

## Deploying the Blueprint

Use `ghpc` to provision the blueprint, supplying your project ID:

```shell
ghpc create --vars project_id=<<PROJECT_ID>> hpc-cluster-intel-select.yaml
```

It will create a set of directories containing Terraform modules and Packer
templates. **Please ignore the printed instructions** in favor of the following:

1. Provision the network and startup scripts that install Intel software.

        ```shell
        terraform -chdir=hpc-intel-select/primary init
        terraform -chdir=hpc-intel-select/primary validate
        terraform -chdir=hpc-intel-select/primary apply
        ```

1. Capture the startup scripts to files that will be used by Packer to build the
   images.

        ```shell
        terraform -chdir=hpc-intel-select/primary output \
            -raw startup_script_startup_controller > \
            hpc-intel-select/packer/controller-image/startup_script.sh
        terraform -chdir=hpc-intel-select/primary output \
            -raw startup_script_startup_compute > \
            hpc-intel-select/packer/compute-image/startup_script.sh
        ```

1. Build the custom Slurm controller image. While this step is executing, you
   may begin the next step in parallel.

        ```shell
        cd hpc-intel-select/packer/controller-image
        packer init .
        packer validate .
        packer build -var startup_script_file=startup_script.sh .
        ```

1. Build the custom Slurm image for login and compute nodes

        ```shell
        cd -
        cd hpc-intel-select/packer/compute-image
        packer init .
        packer validate .
        packer build -var startup_script_file=startup_script.sh .
        ```

1. Provision the Slurm cluster

        ```shell
        cd -
        terraform -chdir=hpc-intel-select/cluster init
        terraform -chdir=hpc-intel-select/cluster validate
        terraform -chdir=hpc-intel-select/cluster apply
        ```

## Connecting to the login node

Once the startup script has completed and Slurm reports readiness, connect to the login node.

1. Open the following URL in a new tab. This will take you to `Compute Engine` >
   `VM instances` in the Google Cloud Console:

        ```text
        https://console.cloud.google.com/compute
        ```

    Ensure that you select the project in which you are provisioning the cluster.

1. Click on the `SSH` button associated with the `slurm-hpc-intel-select-login0`
   instance.

    This will open a separate pop up window with a terminal into our newly created
    Slurm login VM.

## Access the cluster and provision an example job

   **The commands below should be run on the login node.**

1. Create a default ssh key to be able to ssh between nodes:

        ```shell
        ssh-keygen -q -N '' -f ~/.ssh/id_rsa
        cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys
        chmod 0600 ~/.ssh/authorized_keys
        ```

1. Submit an example job:

        ```shell
        cp /var/tmp/dgemm_job.sh .
        sbatch dgemm_job.sh
        ```

## Delete the infrastructure when not in use

> **_NOTE:_** If the Slurm controller is shut down before the auto-scale nodes
> are destroyed then they will be left running.

Open your browser to the VM instances page and ensure that nodes named "compute"
have been shutdown and deleted by the Slurm autoscaler. Delete the remaining
infrastructure in reverse order of creation:

```shell
terraform -chdir=hpc-intel-select/cluster destroy
terraform -chdir=hpc-intel-select/primary destroy
```