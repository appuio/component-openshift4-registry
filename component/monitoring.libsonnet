local cm = import 'lib/cert-manager.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift4_registry;

local nsName = 'syn-monitoring-openshift4-registry';
local targetNamespace = 'openshift-image-registry';

local promInstance =
  if params.monitoring.instance != null then
    params.monitoring.instance
  else
    inv.parameters.prometheus.defaultInstance;

local registryMonitor = prom.ServiceMonitor('openshift-image-registry') {
  metadata+: {
    namespace: nsName,
  },
  spec+: {
    endpoints: [
      {
        bearerTokenFile: '/var/run/secrets/kubernetes.io/serviceaccount/token',
        interval: '30s',
        path: '/extensions/v2/metrics',
        port: '5000-tcp',
        scheme: 'https',
        targetPort: 5000,
        tlsConfig: {
          caFile: '/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt',
          serverName: 'image-registry.%s.svc' % targetNamespace,
        },
      },
    ],
    namespaceSelector: {
      matchNames: [ targetNamespace ],
    },
    selector: {},
  },
};

local registryOperatorMonitor = prom.ServiceMonitor('openshift-image-registry-operator') {
  metadata+: {
    namespace: nsName,
  },
  spec+: {
    endpoints: [
      {
        interval: '60s',
        path: '/metrics',
        scheme: 'https',
        targetPort: 60000,
        tlsConfig: {
          caFile: '/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt',
          serverName: 'image-registry-operator.%s.svc' % targetNamespace,
        },
        metricRelabelings: [
          {
            action: 'keep',
            regex: 'image_registry_.*',
            sourceLabels: [
              '__name__',
            ],
          },
        ],
      },
    ],
    selector: {
      matchLabels: {
        name: 'image-registry-operator',
      },
    },
    namespaceSelector: {
      matchNames: [ targetNamespace ],
    },
  },
};

if params.monitoring.enabled && std.member(inv.applications, 'prometheus') then
  {
    '50_monitoring': [
      prom.RegisterNamespace(
        kube.Namespace(nsName),
        instance=promInstance
      ),
      registryMonitor,
      registryOperatorMonitor,
    ],
  }
else
  std.trace(
    'Monitoring disabled or component `prometheus` not present, '
    + 'not deploying ServiceMonitors',
    {}
  )
