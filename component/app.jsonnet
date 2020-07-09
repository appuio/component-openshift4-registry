local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift4_registry;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('openshift4-registry', params.namespace);

{
  'openshift4-registry': app,
}
