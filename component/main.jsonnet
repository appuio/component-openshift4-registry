local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_registry;

local versionGroup = 'imageregistry.operator.openshift.io/v1';

{
  '00_namespace': kube.Namespace(params.namespace) {
    metadata+: {
      annotations:: {},
      [if std.member(inv.classes, 'components.networkpolicy') then 'labels']+: {
        [inv.parameters.networkpolicy.labels.noDefaults]: 'true',
        [inv.parameters.networkpolicy.labels.purgeDefaults]: 'true',
      },
    },
  },
  '10_image_registry': kube._Object(versionGroup, 'Config', 'cluster') {
    spec+: params.config,
  },
  '20_image_pruning': kube._Object(versionGroup, 'ImagePruner', 'cluster') {
    spec+: params.pruning,
  },
  [if std.objectHas(params, 's3Credentials') then '30_s3_credentials']: kube.Secret('image-registry-private-configuration-user') {
    metadata+: {
      namespace: params.namespace,
    },
    // stringData because password comes from secret ref
    stringData: {
      REGISTRY_STORAGE_S3_ACCESSKEY: params.s3Credentials.accessKey,
      REGISTRY_STORAGE_S3_SECRETKEY: params.s3Credentials.secretKey,
    },
  },
}
