---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE ConstraintKinds     #-}
{-# LANGUAGE RankNTypes          #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell     #-}

module Flowbox.ZMQ.RPC.Server.Server where

import           Control.Monad       (forM_)
import           System.ZMQ4.Monadic (ZMQ)
import qualified System.ZMQ4.Monadic as ZMQ

import           Flowbox.Data.Convert
import           Flowbox.Prelude
import           Flowbox.System.Log.Logger
import qualified Flowbox.Text.ProtocolBuffers     as Proto
import           Flowbox.ZMQ.RPC.Handler          (RPCHandler)
import qualified Flowbox.ZMQ.RPC.Server.Processor as Processor



loggerIO :: LoggerIO
loggerIO = getLoggerIO $(moduleName)


run :: Proto.Serializable request
    => Int -> String -> RPCHandler request -> IO ()
run workerCount endpoint handler = ZMQ.runZMQ $ serve workerCount endpoint handler


handleCalls :: (ZMQ.Receiver t, ZMQ.Sender t, Proto.Serializable request)
            => ZMQ.Socket z t -> RPCHandler request -> ZMQ z ()
handleCalls socket handler = forM_ [1..] $ handleCall socket handler


handleCall :: (ZMQ.Receiver t, ZMQ.Sender t, Proto.Serializable request)
           => ZMQ.Socket z t -> RPCHandler request -> Int -> ZMQ z ()
handleCall socket handler requestID = do
    encoded_request  <- ZMQ.receive socket
    encoded_response <- Processor.process handler encoded_request $ encodeP requestID
    ZMQ.send socket [] encoded_response


serve :: Proto.Serializable request
      => Int -> String -> RPCHandler request -> ZMQ z ()
serve workerCount endpoint  handler = do
    router <- ZMQ.socket ZMQ.Router
    dealer <- ZMQ.socket ZMQ.Dealer
    let internalEndpoint = "inproc://rpcworker"
    ZMQ.bind router endpoint
    ZMQ.bind dealer internalEndpoint
    forM_ [0..workerCount] $ \_ -> ZMQ.async $ do
        rep <- ZMQ.socket ZMQ.Rep
        ZMQ.connect rep internalEndpoint
        handleCalls rep handler
    ZMQ.proxy router dealer Nothing
