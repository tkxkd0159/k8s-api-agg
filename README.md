# sample-apiserver

Demonstration of how to use the k8s.io/apiserver library to build a functional API server.

## Purpose

You may use this code if you want to build an Extension API Server to use with API Aggregation, or to build a stand-alone Kubernetes-style API server.

However, consider two other options:
  * **CRDs**:  if you just want to add a resource to your kubernetes cluster, then consider using Custom Resource Definition a.k.a CRDs.  They require less coding and rebasing.  Read about the differences between Custom Resource Definitions vs Extension API Servers [here](https://kubernetes.io/docs/concepts/api-extension/custom-resources).
  * **Apiserver-builder**: If you want to build an Extension API server, consider using [apiserver-builder](https://github.com/kubernetes-incubator/apiserver-builder) instead of this repo.  The Apiserver-builder is a complete framework for generating the apiserver, client libraries, and the installation program.

If you do decide to use this repository, then the recommended pattern is to fork this repository, modify it to add your types, and then periodically rebase your changes on top of this repo, to pick up improvements and bug fixes to the apiserver.

## Normal Build and Deploy

### Changes to the Types

If you change the API object type definitions in any of the
`pkg/apis/.../types.go` files then you will need to update the files
generated from the type definitions.  To do this, first
[create the vendor directory if necessary](#when-using-go-111-modules)
and then invoke `hack/update-codegen.sh` with `sample-apiserver` as
your current working directory; the script takes no arguments.

### Authentication plugins

The normal build supports only a very spare selection of
authentication methods.  There is a much larger set available in
https://github.com/kubernetes/client-go/tree/master/plugin/pkg/client/auth
.  If you want your server to support one of those, such as `oidc`,
then add an import of the appropriate package to
`sample-apiserver/main.go`.  Here is an example:

``` go
import _ "k8s.io/client-go/plugin/pkg/client/auth/oidc"
```

Alternatively you could add support for all of them, with an import
like this:

``` go
import _ "k8s.io/client-go/plugin/pkg/client/auth"
```

### Build the binary

Next we will want to create a new binary to both test we can build the server and to use for the container image.

From the root of this repo, where ```main.go``` is located, run the following command:
```
export GOOS=linux; go build .
```
if everything went well, you should have a binary called ```sample-apiserver``` present in your current directory.

### Build the container image

Using the binary we just built, we will now create a Docker image and push it to our Dockerhub registry so that we deploy it to our cluster.
There is a sample ```Dockerfile``` located in ```artifacts/simple-image``` we will use this to build our own image.

Again from the root of this repo run the following commands:
```
cp ./sample-apiserver ./artifacts/simple-image/kube-sample-apiserver
docker build -t <YOUR_DOCKERHUB_USER>/kube-sample-apiserver:latest ./artifacts/simple-image
docker push <YOUR_DOCKERHUB_USER>/kube-sample-apiserver
```

### Modify the replication controller

You need to modify the [artifacts/example/deployment.yaml](/artifacts/example/deployment.yaml) file to change the ```imagePullPolicy``` to ```Always``` or ```IfNotPresent```.

You also need to change the image from ```kube-sample-apiserver:latest``` to ```<YOUR_DOCKERHUB_USER>/kube-sample-apiserver:latest```. For example:

```yaml
...
      containers:
      - name: ljs-server
        image: <YOUR_DOCKERHUB_USER>/kube-sample-apiserver:latest
        imagePullPolicy: Always
...
```

Save this file and we are then ready to deploy and try out the sample apiserver.

### Deploy to Kind cluster

```
# create the namespace to run the apiserver in
kubectl create -f artifacts/example/ns.yaml

# create the service account used to run the server
kubectl create -f artifacts/example/sa.yaml -n ljs

# create the rolebindings that allow the service account user to delegate authz back to the kubernetes master for incoming requests to the apiserver
kubectl create -f artifacts/example/auth-delegator.yaml -n kube-system
kubectl create -f artifacts/example/auth-reader.yaml -n kube-system

# create rbac roles and clusterrolebinding that allow the service account user to use admission webhooks
kubectl create -f artifacts/example/rbac.yaml
kubectl create -f artifacts/example/rbac-bind.yaml

# create the service and replication controller
kubectl create -f artifacts/example/deployment.yaml -n ljs
kubectl create -f artifacts/example/service.yaml -n ljs

# create the apiservice object that tells kubernetes about your api extension and where in the cluster the server is located
kubectl create -f artifacts/example/apiservice.yaml
```

## Test that your setup has worked

You should now be able to create the resource type ```Flunder``` which is the resource type registered by the sample apiserver.

```
kubectl create -f artifacts/flunders/01-flunder.yaml
# outputs flunder "my-first-flunder" created
```

You can then get this resource by running:

```
kubectl get flunder my-first-flunder

#outputs
# NAME               KIND
# my-first-flunder   Flunder.v1alpha1.ljs.example.com
```
