{-# LANGUAGE OverloadedStrings #-}

module Empire.Commands.Library
    ( withLibrary
    , listLibraries
    , createLibrary
    -- , getBuffer
    ) where

import           Control.Monad.Except    (throwError)
import           Control.Monad.Reader
import           Control.Monad.State
import qualified Data.Map                as Map
import           Data.Text               (Text)
import qualified Data.Text               as Text
import           Data.Text.IO            as Text
import           Empire.Prelude

import           Empire.Data.AST         (astExceptionToException, astExceptionFromException)
import           Empire.Data.Graph       as Graph
import           Empire.Data.Library     (Library)
import qualified Empire.Data.Library     as Library
import           Empire.Data.Project     (Project)
import qualified Empire.Data.Project     as Project

import           LunaStudio.Data.Library (LibraryId)
import           LunaStudio.Data.Project (ProjectId)

import           Empire.Empire           (Command, Empire)
import qualified Empire.Empire           as Empire
import qualified Empire.Utils.IdGen      as IdGen

createLibrary :: Maybe String -> FilePath -> Empire Library
createLibrary name path = do
    library <- liftIO $ make name path
    Empire.activeFiles . at path ?= library
    return library

make :: Maybe String -> FilePath -> IO Library
make name path = do
    clsGraph <- Graph.defaultClsGraph
    return $ Library.Library name path clsGraph


listLibraries :: Empire [Library]
listLibraries = do
    files <- use Empire.activeFiles
    return $ Map.elems files

data LibraryNotFoundException = LibraryNotFoundException FilePath
    deriving (Show)

instance Exception LibraryNotFoundException where
    toException = astExceptionToException
    fromException = astExceptionFromException

withLibrary :: FilePath -> Command Library a -> Empire a
withLibrary file cmd = do
    zoom (Empire.activeFiles . at file) $ do
        libMay <- get
        notifEnv <- ask
        case libMay of
            Nothing  -> throwM $ LibraryNotFoundException file
            Just lib -> do
                let result = (_2 %~ Just) <$> Empire.runEmpire notifEnv lib cmd
                Empire.empire $ const $ const result
                -- (result, state) <- liftIO $ Empire.runEmpire notifEnv lib cmd
                -- put $ Just state
                -- -- return result
                -- Empire.empire $ const $ const result
--
-- getBuffer :: FilePath -> Maybe (Int, Int) -> Empire Text
-- getBuffer path Nothing = withLibrary path $ do
--     source <- use $ Library.body . Graph.code
--     return source
