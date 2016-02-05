{-# LANGUAGE DataKinds                 #-}
{-# LANGUAGE DeriveDataTypeable        #-}
{-# LANGUAGE FlexibleInstances         #-}
{-# LANGUAGE FunctionalDependencies    #-}
{-# LANGUAGE GADTs                     #-}
{-# LANGUAGE IncoherentInstances       #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE OverlappingInstances      #-}
{-# LANGUAGE PolyKinds                 #-}
{-# LANGUAGE UndecidableInstances      #-}






import           Data.Typeable

data Foo1 a = Foo1 a deriving (Show, Typeable)
data Foo2 a b = Foo2 a b deriving (Show, Typeable)

class Test a where
    test :: a -> Int

data UV = UV deriving (Show, Typeable)

data Id0 = Id0 deriving (Show, Typeable)
data Id1 t1 = Id1 deriving (Show, Typeable)
data Id2 t1 t2 = Id2 deriving (Show, Typeable)
data Id3 t1 t2 t3 = Id3 deriving (Show, Typeable)
data Id4 t1 t2 t3 t4 = Id4 deriving (Show, Typeable)
data Id5 t1 t2 t3 t4 t5 = Id5 deriving (Show, Typeable)

c2 :: Monad (m a) => a -> b -> m a b
c2 = undefined

instance  KnownType a=>Num a
instance  KnownType a =>Monad a


instance  (m ~ Id1) =>Test (Foo1 (m a))  where
    test _ = 5


class KnownType a where
    matchKnown :: Proxy a -> Proxy a
    matchKnown = undefined

instance KnownType Int

instance KnownType Foo1
instance KnownType Foo2

instance  (KnownType m, KnownType a) =>KnownType (m a)
instance  (a~Id0) =>KnownType (a :: *)
instance  (a~Id1)=>KnownType (a :: * -> *)
instance  (a~Id2) =>KnownType (a :: * -> * -> *)



toProxy :: a -> Proxy a
toProxy _ = Proxy


tm _ = 5


data Y a = Y a deriving (Show)

main = do
    print $ typeOf $ matchKnown $ toProxy $ (return (5))
    print $ typeOf $ matchKnown $ toProxy $ (5)
    print $ typeOf $ matchKnown $ toProxy $ (Foo1 (return 5))
    print $ typeOf $ matchKnown $ toProxy $ (Foo2 (return 5) (return 5))

    print $ tm $ typeOf $ matchKnown $ toProxy $ (c2 (5 :: Int) (5 :: Int))

    print "hello"


    --print $ (return 5 :: Y Int)

---- OUTPUT
--    Proxy (Id1 Id0)
--    Proxy Id0
--    Proxy (Foo1 (Id1 Id0))
--    Proxy (Foo2 (Id1 Id0) (Id1 Id0))
--    Proxy (Id2 Int Int)
--    "hello"
