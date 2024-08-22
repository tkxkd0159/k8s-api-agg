# k8s-apiserver-aggregation-sample

Demonstration of how to use the k8s.io/apiserver library to build a functional API server.

- [Purpose](#purpose)
- [Normal Build and Deploy](#normal-build-and-deploy)
  - [Changes to the Types](#changes-to-the-types)
  - [Authentication plugins](#authentication-plugins)
  - [Build the binary and the container image](#build-the-binary-and-the-container-image)
  - [Deploy to Kind cluster](#deploy-to-kind-cluster)
- [Test that your setup has worked](#test-that-your-setup-has-worked)

## Purpose

You may use this code if you want to build an Extension API Server to use with API Aggregation, or to build a stand-alone Kubernetes-style API server.

However, consider two other options:
  * **CRD**:  if you just want to add a resource to your kubernetes cluster, then consider using Custom Resource Definition a.k.a CRDs.  They require less coding and rebasing.  Read about the differences between Custom Resource Definitions vs Extension API Servers [here](https://kubernetes.io/docs/concepts/api-extension/custom-resources).
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

### Build the binary and the container image
```sh
./hack/build-image.sh [--push]
```

### Deploy to Kind cluster

```sh
# create the namespace to run the apiserver in
kubectl create -f artifacts/example/ns.yaml

# create the service account used to run the server
kubectl create -f artifacts/example/sa.yaml -n wardle

# create the rolebindings that allow the service account user to delegate authz back to the kubernetes master for incoming requests to the apiserver
kubectl create -f artifacts/example/auth-delegator.yaml -n kube-system
kubectl create -f artifacts/example/auth-reader.yaml -n kube-system

# create rbac roles and clusterrolebinding that allow the service account user to use admission webhooks
kubectl create -f artifacts/example/rbac.yaml
kubectl create -f artifacts/example/rbac-bind.yaml

# create the service and replication controller
kubectl create -f artifacts/example/deployment.yaml -n wardle
kubectl create -f artifacts/example/service.yaml -n wardle

# create the apiservice object that tells kubernetes about your api extension and where in the cluster the server is located
kubectl create -f artifacts/example/apiservice.yaml
```

Verify the deployed resources:
```sh
kubectl get svc -n wardle api
kubectl get endpoints -n wardle api
kubectl get pods -n wardle --selector=apiserver=true
kubectl describe pods -n wardle --selector=apiserver=true # check the logs
kubectl get apiservice v1alpha1.wardle.example.com
```

## Test that your setup has worked

You should now be able to create the resource type ```Flunder``` which is the resource type registered by the sample apiserver.
```sh
kubectl create -f artifacts/flunders/01-flunder.yaml
```

You can then get this resource by running:
```sh
kubectl get flunder my-first-flunder -o yaml
kubectl get --raw /apis/wardle.example.com/v1alpha1/flunders
kubectl get --raw /apis/wardle.example.com/v1alpha1/namespaces/default/flunders
kubectl get --raw /apis/wardle.example.com/v1alpha1/namespaces/default/flunders/my-first-flunder
kubectl get --raw /apis/wardle.example.com/v1alpha1/namespaces/wrongnamespace/flunders
```
