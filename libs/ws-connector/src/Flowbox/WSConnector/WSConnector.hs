---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Flowbox Team <contact@flowbox.io>, 2015
-- Proprietary and confidential
-- Unauthorized copying of this file, via any medium is strictly prohibited
---------------------------------------------------------------------------
{-# LANGUAGE RankNTypes #-}

module Flowbox.WSConnector.WSConnector where

import           Control.Concurrent    (forkIO, threadDelay)
import           Control.Monad         (forever)
import qualified Data.ByteString       as B
import qualified Data.ByteString.Char8 as BC
import qualified Network.WebSockets    as WS
import qualified System.ZMQ4.Monadic   as ZMQ

import           Flowbox.Bus.Bus               (Bus)
import qualified Flowbox.Bus.Bus               as Bus
import qualified Flowbox.Bus.Data.Flag         as Flag
import qualified Flowbox.Bus.Data.Message      as Message
import qualified Flowbox.Bus.Data.MessageFrame as MessageFrame
import qualified Flowbox.Bus.EndPoint          as EP
import qualified Flowbox.Config.Config         as Config
import           Flowbox.Control.Error
import           Flowbox.Prelude


fromWeb :: WS.Connection -> Bus ()
fromWeb conn = do
    forever $ do
        webMessage <- liftIO $ do WS.receiveData conn
        Bus.sendByteString webMessage

    return ()

toWeb :: WS.Connection -> Bus ()
toWeb  conn = do
    let prefixTopic = ""
    Bus.subscribe prefixTopic

    forever $ do
        messageBus <- Bus.receiveByteString
        liftIO $ do WS.sendTextData conn messageBus

    return ()

runBus :: EP.BusEndPoints -> Bus a -> IO (Either Bus.Error a)
runBus e b = ZMQ.runZMQ $ Bus.runBus e b

application ::  EP.BusEndPoints -> WS.ServerApp
application busEndPoints pending = do
    conn <- WS.acceptRequest pending

    let pingTime = 30
    WS.forkPingThread conn pingTime

    _ <- forkIO $ eitherToM' $ runBus busEndPoints $ fromWeb conn
    void $ runBus busEndPoints $ toWeb conn

run :: IO ()
run = do
    busEndPoints <- EP.clientFromConfig <$> Config.load
    WS.runServer "0.0.0.0" 8088 $ application busEndPoints
