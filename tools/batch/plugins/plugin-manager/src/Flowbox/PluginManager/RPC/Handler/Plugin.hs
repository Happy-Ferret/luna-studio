---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE TemplateHaskell #-}
module Flowbox.PluginManager.RPC.Handler.Plugin where

import Control.Monad.Trans.State

import           Flowbox.Bus.RPC.RPC                                  (RPC)
import           Flowbox.Control.Error
import           Flowbox.Data.Convert
import           Flowbox.PluginManager.Context                        (Context)
import qualified Flowbox.PluginManager.Context                        as Context
import           Flowbox.PluginManager.Plugin.Handle                  (PluginHandle)
import qualified Flowbox.PluginManager.Plugin.Handle                  as PluginHandle
import qualified Flowbox.PluginManager.Plugin.Map                     as PluginMap
import qualified Flowbox.PluginManager.Plugin.Plugin                  as Plugin
import           Flowbox.PluginManager.Proto.Plugin                   ()
import           Flowbox.Prelude                                      hiding (Context, error, id)
import           Flowbox.System.Log.Logger
import qualified Generated.Proto.PluginManager.Plugin.Add.Request     as Add
import qualified Generated.Proto.PluginManager.Plugin.Add.Update      as Add
import qualified Generated.Proto.PluginManager.Plugin.List.Request    as List
import qualified Generated.Proto.PluginManager.Plugin.List.Status     as List
import qualified Generated.Proto.PluginManager.Plugin.Lookup.Request  as Lookup
import qualified Generated.Proto.PluginManager.Plugin.Lookup.Status   as Lookup
import qualified Generated.Proto.PluginManager.Plugin.Remove.Request  as Remove
import qualified Generated.Proto.PluginManager.Plugin.Remove.Update   as Remove
import qualified Generated.Proto.PluginManager.Plugin.Restart.Request as Restart
import qualified Generated.Proto.PluginManager.Plugin.Restart.Update  as Restart
import qualified Generated.Proto.PluginManager.Plugin.Start.Request   as Start
import qualified Generated.Proto.PluginManager.Plugin.Start.Update    as Start
import qualified Generated.Proto.PluginManager.Plugin.Stop.Request    as Stop
import qualified Generated.Proto.PluginManager.Plugin.Stop.Update     as Stop



logger :: LoggerIO
logger = getLoggerIO $moduleName

-------- public api -------------------------------------------------

add :: Add.Request -> RPC Context IO Add.Update
add request@(Add.Request tplugin) = do
    ctx <- lift get
    let plugins = Context.plugins ctx
        id      = PluginMap.uniqueID plugins
    plugin <- decodeE tplugin
    lift $ put $ ctx { Context.plugins = PluginMap.insert id (PluginHandle.mk plugin) plugins}
    return $ Add.Update request (encodeP id)


remove :: Remove.Request -> RPC Context IO Remove.Update
remove request@(Remove.Request tid) = do
    ctx <- lift get
    let id      = decodeP tid
        plugins = Context.plugins ctx
    lift $ put $ ctx { Context.plugins = PluginMap.delete id plugins}
    return $ Remove.Update request


list :: List.Request -> RPC Context IO List.Status
list request = do
    ctx <- lift get
    let plugins = Context.plugins ctx
    pluginInfos <- safeLiftIO $ mapM PluginHandle.info $ PluginMap.elems plugins
    return $ List.Status request (encode $ zip (PluginMap.keys plugins) pluginInfos)


-- TODO [PM] : Duplikacja kodu
lookup :: Lookup.Request -> RPC Context IO Lookup.Status
lookup request@(Lookup.Request tid) = do
    ctx <- lift get
    let id      = decodeP tid
        plugins = Context.plugins ctx
    pluginHandle <- PluginMap.lookup id plugins <??> "Cannot find plugin with id=" ++ show id
    pluginInfo   <- safeLiftIO $ PluginHandle.info pluginHandle
    return $ Lookup.Status request (encode (id, pluginInfo))


start :: Start.Request -> RPC Context IO Start.Update
start request@(Start.Request tid) = do
    let id = decodeP tid
    _ <- withPluginHandle id (PluginHandle.start . view PluginHandle.plugin)
    return $ Start.Update request


stop :: Stop.Request -> RPC Context IO Stop.Update
stop request@(Stop.Request tid) = do
    let id = decodeP tid
    _ <- withPluginHandle id PluginHandle.stop
    return $ Stop.Update request


restart :: Restart.Request -> RPC Context IO Restart.Update
restart request@(Restart.Request tid) = do
    let id = decodeP tid
    _ <- withPluginHandle id PluginHandle.restart
    return $ Restart.Update request


withPluginHandle :: Plugin.ID -> (PluginHandle -> IO PluginHandle) -> RPC Context IO PluginHandle
withPluginHandle id operation = do
    ctx <- lift get
    let plugins = Context.plugins ctx
    pluginHandle    <- PluginMap.lookup id plugins <??> "Cannot find plugin with id=" ++ show id
    newPluginHandle <- safeLiftIO $ operation pluginHandle
    lift $ put $ ctx { Context.plugins = PluginMap.insert id newPluginHandle plugins}
    return newPluginHandle
