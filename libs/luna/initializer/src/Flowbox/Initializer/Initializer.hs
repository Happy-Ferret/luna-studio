---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE TemplateHaskell #-}

module Flowbox.Initializer.Initializer where

import           Control.Applicative
import           Control.Monad
import qualified Data.String.Utils   as StringUtils
import qualified System.IO           as IO

import           Flowbox.Config.Config              (Config)
import qualified Flowbox.Config.Config              as Config
import           Flowbox.Prelude                    hiding (error)
import qualified Flowbox.System.Directory.Directory as Directory
import           Flowbox.System.FilePath            (expand')
import           Flowbox.System.Log.Logger
import qualified Flowbox.System.Process             as Process
import           Flowbox.System.UniPath             (UniPath)
import qualified Flowbox.System.UniPath             as UniPath



logger :: LoggerIO
logger = getLoggerIO $(moduleName)


successfullInstallFilePath :: Config -> IO UniPath
successfullInstallFilePath config = UniPath.expand $ UniPath.append "installed" localPath where
    localPath = UniPath.fromUnixString $ Config.path $ Config.local config


isAlreadyInitilized :: Config -> IO Bool
isAlreadyInitilized config = do
    let local  = Config.local  config
    localCabal <- expand' $ Config.cabal local
    localPkgDb <- expand' $ Config.pkgDb local
    logger debug "Checking for Flowbox configuration."
    exists_localCabal <- Directory.doesDirectoryExist $ UniPath.fromUnixString localCabal
    exists_localPkgDb <- Directory.doesDirectoryExist $ UniPath.fromUnixString localPkgDb
    exists_installed  <- Directory.doesFileExist =<< successfullInstallFilePath config
    let exists = exists_localCabal && exists_localPkgDb && exists_installed
    if exists
        then logger debug "Configuration already exists."
        else logger debug "Configuration does not exist or is broken."
    return exists


initializeIfNeeded :: Config -> IO ()
initializeIfNeeded config = do
    initialized <- isAlreadyInitilized config
    when (not initialized) (clear config *> initialize config)


initialize :: Config -> IO ()
initialize config = do
    logger info "Configuring Flowbox for the first use. Please wait..."
    let root    = Config.root config
        local   = Config.local  config
    localCabal  <- expand' $ Config.cabal local
    localPkgDb  <- expand' $ Config.pkgDb local
    ghcPkgBin   <- expand' $ Config.ghcPkg $ Config.wrappers  $ config
    cabalConfT  <- expand' $ Config.cabal  $ Config.templates $ config
    cabalConf   <- expand' $ Config.cabal  $ Config.config    $ config
    cabalBin    <- expand' $ Config.cabal  $ Config.wrappers  $ config
    fbInstall   <- expand' $ Config.path root
    fbHomeCabal <- expand' $ Config.cabal local
    Directory.createDirectoryIfMissing True $ UniPath.fromUnixString localCabal
    Directory.createDirectoryIfMissing True $ UniPath.fromUnixString localPkgDb
    Process.runProcess Nothing ghcPkgBin ["recache", "--package-db=" ++ localPkgDb]

    cabalConfTContent <- IO.readFile cabalConfT
    let cabalConfContent = StringUtils.replace "${FB_INSTALL}"    fbInstall
                         $ StringUtils.replace "${FB_HOME_CABAL}" fbHomeCabal cabalConfTContent
    IO.writeFile cabalConf cabalConfContent
    Process.runProcess Nothing cabalBin ["update"]
    Directory.touchFile =<< successfullInstallFilePath config
    logger info "Flowbox configured successfully."


clear :: Config -> IO ()
clear config = do
    logger info "Cleaning Flowbox configuration."
    localPath <- UniPath.expand $ UniPath.fromUnixString $ Config.path $ Config.local config
    whenM (Directory.doesDirectoryExist localPath) $
        Directory.removeDirectoryRecursive localPath
