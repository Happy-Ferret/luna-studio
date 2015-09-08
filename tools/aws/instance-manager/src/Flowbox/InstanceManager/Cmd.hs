---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Flowbox.InstanceManager.Cmd where

import Flowbox.Prelude



data Prog    = Prog { cmd     :: Command
                    , region  :: String
                    , noColor :: Bool
                    , verbose :: Int
                    }
             deriving Show


data Command = Start     Options
             | Stop      Options
             | Get       Options
             | Terminate Options
             | Version   Options
             deriving Show


data Options = StartOptions     { ami            :: String
                                , machine        :: String
                                , credentialPath :: String
                                , keyName        :: String
                                }
             | StopOptions      { force          :: Bool
                                , credentialPath :: String
                                }
             | GetOptions       { credentialPath :: String
                                }
             | TerminateOptions { credentialPath :: String
                                }
             | VersionOptions   { numeric :: Bool
                                }
             deriving Show
