local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_registry;

local tls = import 'tls.libsonnet';

local versionGroup = 'imageregistry.operator.openshift.io/v1';

local hasNewRoutes = std.length(std.objectFields(params.routes)) > 0;
local registryConfigSpec =
  params.config {
    [if hasNewRoutes then 'routes']: std.filter(
      function(it) it != null,
      [
        if params.routes[r] != null then
          params.routes[r] {
            name: r,
          }
        for r in std.objectFields(params.routes)
      ]
    ),
  };

{
  '00_namespace': kube.Namespace(params.namespace) {
    metadata+: {
      annotations:: {},
      [if std.member(inv.applications, 'networkpolicy') then 'labels']+: {
        [inv.parameters.networkpolicy.labels.noDefaults]: 'true',
        [inv.parameters.networkpolicy.labels.purgeDefaults]: 'true',
      },
    },
  },
  '10_image_registry':
    kube._Object(versionGroup, 'Config', 'cluster') {
      spec+: registryConfigSpec,
    },
  '20_image_pruning':
    kube._Object(versionGroup, 'ImagePruner', 'cluster') {
      spec+: params.pruning,
    },
  [if std.objectHas(params, 's3Credentials') then '30_s3_credentials']:
    kube.Secret('image-registry-private-configuration-user') {
      metadata+: {
        namespace: params.namespace,
      },
      // stringData because password comes from secret ref
      stringData: {
        REGISTRY_STORAGE_S3_ACCESSKEY: params.s3Credentials.accessKey,
        REGISTRY_STORAGE_S3_SECRETKEY: params.s3Credentials.secretKey,
      },
    },
  [if std.length(tls.secrets) > 0 then '30_secrets']:
    tls.secrets,
  [if std.length(tls.certs) > 0 then '30_cert_manager_certs']:
    tls.certs,
}
