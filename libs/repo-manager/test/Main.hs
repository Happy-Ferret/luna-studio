---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
module Main where

import           Flowbox.Prelude
--import qualified Flowbox.RepoManager.VCS.Git.Git as Git --import qualified Flowbox.RepoManager.VCS.VCS     as VCS
--import qualified Flowbox.RepoManager.VCS.VCS  as VCS
--import qualified Flowbox.RepoManager.Data.Item.Config as Config
--import qualified           System.Environment              as Environment
--import qualified Flowbox.RepoManager.Data.Repository as Repository

main :: IO ()
main = do
     return ()
     --print =<< Config.loadItem "repo/packages/games-action/pacman/pacman-0.1.1.config"
     --print =<< Config.loadItem "test/test.config"

     --let vcs = Git.createVCS VCS.Git "repo/packages" "git@github.com:dobry/packages.git"
     ----print =<< Repository.buildRepository vcs

     --Git.remove vcs

     --repo <- Repository.initRepository vcs
     --print repo

     ----Git.remove vcs

     --newRepo <- Repository.updateRepository vcs
     --print newRepo

     --print $ Repository.searchRepository repo "c"
     --print $ Repository.searchRepository repo "^c"
     --print $ Repository.searchRepository repo "(not|man)"



--main = do
--          args <- Environment.getArgs
--          case args of
--            []         -> Main.clone
--            "update":_ -> Main.update
--            "remove":_ -> Main.remove
--            "clone": _ -> Main.clone
--            _other     -> Main.clone

--create ::  VCS.VCS
--create = Git.createVCS VCS.Git "repo" "packages" "git@github.com:dobry/packages.git"

--clone :: IO ()
--clone = do
--           _ <- Git.clone create
--           return ()

--update :: IO ()
--update = do
--            _ <- Git.update create
--            return ()

--remove :: IO ()
--remove = do
--            _ <- Git.remove create
--            return ()

