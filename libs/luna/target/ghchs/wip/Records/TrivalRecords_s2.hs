{-
  The following is a prototype implementation of the plan for
  overloaded record fields in GHC, described at

  http://ghc.haskell.org/trac/ghc/wiki/Records/OverloadedRecordFields/Plan

  This version does not support lens integration.
-}

{-# LANGUAGE DataKinds                 #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE FlexibleInstances         #-}
{-# LANGUAGE KindSignatures            #-}
{-# LANGUAGE MultiParamTypeClasses     #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE PolyKinds                 #-}
{-# LANGUAGE RankNTypes                #-}
{-# LANGUAGE TypeFamilies              #-}
{-# LANGUAGE TypeOperators             #-}
{-# LANGUAGE UndecidableInstances      #-}

module TrivialRecords where

import           Control.Applicative
import           GHC.TypeLits


-- These class and type family declarations go in base:

type family GetResult (r :: *) (f :: Symbol) :: *

class Has r (f :: Symbol) t where
  getField :: proxy f -> r -> t


-- Some example datatypes...

data V k = MkV { _foo'' :: Int, _bar'' :: k Int }
data X a = MkX { _foo''' :: Int, _bar''' :: a }


type instance GetResult (V k) "foo" = Int
instance t ~ GetResult (V k) "foo" => Has (V k) "foo" t where
  getField _ (MkV x _) = x

type instance GetResult (V k) "bar" = k Int
instance t ~ GetResult (V k) "bar" => Has (V k) "bar" t where
  getField _ (MkV _ y) = y


type instance GetResult (X k) "foo" = Int
instance t ~ GetResult (X k) "foo" => Has (X k) "foo" t where
  getField _ (MkX x _) = x


type instance GetResult (X a) "bar" = a
instance t ~ GetResult (X a) "bar" => Has (X a) "bar" t where
  getField _ (MkX _ y) = y


--type instance GetResult (V k) "foo" = Int
--instance t ~ Int => Has (V k) "foo" t where
--  getField _ (MkV x _) = x

--type instance GetResult (V k) "bar" = k Int
--instance t ~ k Int => Has (V k) "bar" t where
--  getField _ (MkV _ y) = y


--type instance GetResult (X k) "foo" = Int
--instance t ~ Int => Has (X k) "foo" t where
--  getField _ (MkX x _) = x


--type instance GetResult (X a) "bar" = a
--instance t ~ a => Has (X a) "bar" t where
--  getField _ (MkX _ y) = y

test = getField (Proxy :: Proxy "foo") . getField (Proxy :: Proxy "bar")


data Proxy k = Proxy

--main = do
--  print $ test $ MkX 5 (MkV 5 [4])
--  print "end"
