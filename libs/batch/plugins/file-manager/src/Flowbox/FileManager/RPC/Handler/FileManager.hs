---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell       #-}

module Flowbox.FileManager.RPC.Handler.FileManager where

import           Flowbox.Bus.RPC.RPC                                     (RPC)
import           Flowbox.Data.Convert
import           Flowbox.FileManager.FileManager                         (FileManager)
import qualified Flowbox.FileManager.FileManager                         as FileManager
import           Flowbox.Prelude
import           Flowbox.System.Log.Logger
import qualified Generated.Proto.FileManager.FileManager.Ping.Request    as Ping
import qualified Generated.Proto.FileManager.FileManager.Ping.Status     as Ping
import qualified Generated.Proto.FileManager.FileManager.Resolve.Request as Resolve
import qualified Generated.Proto.FileManager.FileManager.Resolve.Status  as Resolve
import qualified Generated.Proto.FileManager.FileSystem.Stat.Request     as Stat
import qualified Generated.Proto.FileManager.FileSystem.Stat.Status      as Stat



logger :: LoggerIO
logger = getLoggerIO $moduleName

-------- public api -------------------------------------------------

ping :: Ping.Request -> RPC ctx IO Ping.Status
ping request = do
    logger info "Ping received"
    return $ Ping.Status request


resolve :: FileManager fm ctx => fm
        -> Resolve.Request -> RPC ctx IO Resolve.Status
resolve fm request@(Resolve.Request tpath) = do
    let path = decodeP tpath
    resolved <- FileManager.resolvePath fm path
    return $ Resolve.Status request $ encodeP resolved


stat :: FileManager fm ctx => fm
     -> Stat.Request -> RPC ctx IO Stat.Status
stat fm request@(Stat.Request tpath) = do
    let path = decodeP tpath
    Stat.Status request <$> FileManager.stat fm path
