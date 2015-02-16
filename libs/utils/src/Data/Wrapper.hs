---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

{-# LANGUAGE DefaultSignatures #-}
{-# LANGUAGE OverlappingInstances #-}
{-# LANGUAGE UndecidableInstances #-}

module Data.Wrapper where

import Control.Monad.Trans
import Prelude


----------------------------------------------------------------------------------
-- Type classes
----------------------------------------------------------------------------------

class Wrap m where
    wrap :: a -> m a

    default wrap :: Monad m => a -> m a
    wrap = return

class Unwrap m where
    unwrap :: m a -> a

class (Wrap m, Unwrap m) => Wrapper m



class WrapT t where
    wrapT :: m a -> t m a

    default wrapT :: (MonadTrans t, Monad m) => m a -> t m a
    wrapT = lift

class UnwrapT t where
    unwrapT :: t m a -> m a

class (WrapT t, UnwrapT t) => WrapperT t


----------------------------------------------------------------------------------
-- Utils
----------------------------------------------------------------------------------

rewrap :: (Unwrap m, Wrap n) => m a -> n a
rewrap = wrap . unwrap


----------------------------------------------------------------------------------
-- Instances
----------------------------------------------------------------------------------

instance (Wrap a, Unwrap a) => Wrapper a
instance (WrapT a, UnwrapT a) => WrapperT a