Framework = {}

if GetResourceState("qb-core"):find("start") then
    Framework.initials = "qb"
    Framework.resourceName = "qb-core"
    Framework.object = exports[Framework.resourceName]:GetCoreObject()
elseif GetResourceState("es_extended"):find("start") then
    Framework.initials = "esx"
    Framework.resourceName = "es_extended"
    Framework.object = exports[Framework.resourceName]:getSharedObject()
end