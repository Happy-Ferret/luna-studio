---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE RankNTypes      #-}
{-# LANGUAGE TemplateHaskell #-}

module Flowbox.Bus.RPC.Server.Server where

import           Flowbox.Bus.EndPoint             (BusEndPoints)
import           Flowbox.Bus.RPC.HandlerMap       (HandlerMap, HandlerMapWithCid)
import qualified Flowbox.Bus.RPC.HandlerMap       as HandlerMap
import qualified Flowbox.Bus.RPC.Server.Processor as Processor
import qualified Flowbox.Bus.Server               as Server
import           Flowbox.Prelude                  hiding (error)
import           Flowbox.System.Log.Logger



logger :: LoggerIO
logger = getLoggerIO $(moduleName)


run :: BusEndPoints -> s -> HandlerMap s IO -> IO (Either String ())
run endPoints s handlerMap =
    Server.runState endPoints (HandlerMap.topics handlerMap) s $ const $ Processor.process handlerMap

runWithCid :: BusEndPoints -> s -> HandlerMapWithCid s IO -> IO (Either String ())
runWithCid endPoints s handlerMap =
    Server.runState endPoints (HandlerMap.topicsWithCid handlerMap) s $ Processor.processWithCid handlerMap

