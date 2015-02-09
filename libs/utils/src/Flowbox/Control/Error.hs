---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts #-}

module Flowbox.Control.Error (
  module Flowbox.Control.Error
, module X
, MonadIO
, liftIO
) where

import           Control.Error             as X hiding (runScript)
import qualified Control.Exception         as Exc
import           Control.Monad.IO.Class    (MonadIO, liftIO)
import           Control.Monad.Trans.Class (MonadTrans)
import qualified Data.Maybe                as Maybe

import Flowbox.Prelude



runScript :: Script a -> IO a
runScript s = do
    e <- runEitherT s
    case e of
        Left  m -> fail m
        Right a -> return a

infixl 4 <?.>
(<?.>) :: Monad m => Maybe b -> String -> m b
val <?.> m = Maybe.maybe (fail m) return val


infixl 4 <??&.>
(<??&.>) :: Monad m => m (Maybe b) -> String -> m b
val <??&.> m = Maybe.maybe (fail m) return =<< val


infixl 4 <?>
(<?>) :: Maybe b -> a -> Either a b
val <?> m = Maybe.maybe (Left m) Right val


infixl 4 <?&>
(<?&>) :: Either a (Maybe b) -> a -> Either a b
val <?&> m = Maybe.maybe (Left m) Right =<< val


infixl 4 <??>
(<??>) :: Monad m => Maybe b -> a -> EitherT a m b
val <??> m = Maybe.maybe (left m) return val


infixl 4 <??&>
(<??&>) :: Monad m => EitherT a m (Maybe b) -> a -> EitherT a m b
val <??&> m = Maybe.maybe (left m) return =<< val


assertIO :: Monad m => Bool -> String -> m ()
assertIO condition msg = unless condition $ fail msg


assert :: Bool -> a -> Either a ()
assert condition msg = unless condition $ Left msg

assertE :: Monad m => Bool -> a -> EitherT a m ()
assertE condition msg = unless condition $ left msg


-- FIXME [PM] : find better name
safeLiftIO :: MonadIO m => IO b -> EitherT String m b
safeLiftIO = safeLiftIO' show


safeLiftIO' :: MonadIO m => (Exc.SomeException -> a) -> IO b -> EitherT a m b
safeLiftIO' excMap operation  = do
    result <- liftIO $ Exc.try operation
    hoistEither $ fmapL excMap result


eitherToM :: (MonadIO m, Show a) => Either a b -> m b
eitherToM = either (fail . show) return


eitherToM' :: (MonadIO m, Show a) => m (Either a b) -> m b
eitherToM' action = action >>= eitherToM


eitherStringToM :: MonadIO m => Either String b -> m b
eitherStringToM = either fail return


eitherStringToM' :: MonadIO m => m (Either String b) -> m b
eitherStringToM' action = action >>= eitherStringToM


catchEither :: (MonadTrans t, Monad (t m), Monad m)
            => (e -> t m b) -> EitherT e m b -> t m b
catchEither handler fun = do
    result <- lift $ runEitherT fun
    case result of
        Left  e -> handler e
        Right r -> return r

hoistEitherWith :: Monad m => (e1 -> e) -> Either e1 a -> EitherT e m a
hoistEitherWith conv = hoistEither . fmapL conv
