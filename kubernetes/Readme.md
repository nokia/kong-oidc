# Deploying Kong Gateway with OIDC Plugin on Kubernetes Using Helm
This folder provides an example of how to deploy the Kong Gateway with the OIDC plugin on a Kubernetes cluster using Helm. This example includes:

- A Helm chart for deploying Kong Gateway with the OIDC plugin.
- A Dockerfile to build a custom Kong image with the OIDC plugin pre-installed.

## Prerequisites
Before deploying, ensure you have the following:

- A Kubernetes cluster.
- Helm installed and configured (helm version).
- kubectl installed and configured (kubectl version).
- Docker installed to build the custom Kong image.

## Folder Structure

```yaml
kubernetes
    ├── helm-chart-kong-oidc/  
    │   ├── Chart.yaml                # Metadata for the Helm chart  
    │   ├── oidc_values.yaml          # file containing values to override in the helmchart 
    │   ├── .helmignore               # Helmignore file
    │   ├── charts/                   # Repository for subcharts  
    │   │   └── kong-15.1.0.tgz       # Base bitnami/kong helm chart
    ├── Dockerfile                    # Dockerfile to build the Kong image with the OIDC plugin
    └── README.md                     # This file
```

## Instructions
### Step 1: Build the Custom Kong Image
1- Navigate to the directory containing the Dockerfile.

2- Build the Docker image:
```bash
docker build -t <your-dockerhub-username>/kong-oidc:latest .  
```
3- Push the image to your Docker registry:
```bash
docker push <your-dockerhub-username>/kong-oidc:latest
```

PS : If you want to save the trouble of creating your docker image and push it to your dockerhub registry, you can use the docker image that I already provided on my [docker registry](#https://hub.docker.com/repository/docker/malekeljaouadi/bitnami-kong-with-oidc) that I am already using it in the provided helm chart.

### Step 2: Deploy Kong Gateway with Helm
1- Navigate to the helmchart directory.

2- Update the values.yaml file with your custom configurations, such as:
- The Docker image URL for the custom Kong image.
- The OIDC plugin configuration (e.g., client ID, client secret, and discovery URL).

3- Install the Helm chart:
```bash
helm install kong-oidc ./ --namespace kong -f oidc_values.yaml --create-namespace  

```

## Cleanup
To delete the deployment, run:

```bash
helm uninstall kong-oidc --namespace kong  
kubectl delete namespace kong  
```

## License
This example follows the licensing terms of the kong-oidc repository.
