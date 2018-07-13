{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
{-# OPTIONS_GHC -fno-warn-orphans  #-}

module Empire.Env where

import           Prologue

import           Control.Concurrent.STM.TChan  (TChan)
import           Control.Concurrent.MVar       (MVar)
import           Empire.Data.Graph             (CommandState(..), Graph, ClsGraph, defaultPMState)
import qualified Empire.Empire                 as Empire
import           LunaStudio.API.AsyncUpdate    (AsyncUpdate)
import           LunaStudio.Data.GraphLocation (GraphLocation (..))
import           ZMQ.Bus.Config                (Config)
import qualified ZMQ.Bus.Config                as Config
import           ZMQ.Bus.Data.Message          (Message)

instance Show (TChan Message) where
    show _ = "(TChan)"

data Env = Env { _empireEnv   :: CommandState Empire.Env
               , _empireNotif :: Empire.CommunicationEnv
               , _formatted   :: Bool
               , _toBusChan   :: TChan Message
               , _projectRoot :: FilePath
               , _config      :: Config
               }
makeLenses ''Env

make :: TChan Message
     -> TChan AsyncUpdate
     -> MVar Empire.TCRequest
     -> MVar Empire.SymbolMap
     -> MVar Empire.CompiledModules
     -> FilePath
     -> IO Env
make toBus fromEmpire tc sm imps fp = do
    zmqConfig <- Config.load
    pmState   <- defaultPMState
    let cmdState = CommandState pmState def
    return $ Env cmdState (Empire.CommunicationEnv fromEmpire tc sm imps) True toBus fp zmqConfig

newtype LoggerEnv = LoggerEnv { _formatLog :: Bool }
makeLenses ''LoggerEnv

instance Default LoggerEnv where
    def = LoggerEnv True
