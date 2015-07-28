{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RankNTypes #-}

module Data.Convert.Base where


----------------------------------------------------------------------
-- Conversions
----------------------------------------------------------------------

class MaybeConvertible a e b | a b -> e where
    tryConvert :: a -> Either e b

class Convertible a b where
    convert :: a -> b

class Castable a b where
    cast :: a -> b

type IsoMaybeConvertible a e b = (MaybeConvertible a e b, MaybeConvertible b e a)
type IsoConvertible      a b   = (Convertible      a b  , Convertible      b a  )
type IsoCastable         a b   = (Castable         a b  , Castable         b a  )

unsafeConvert :: Show e => MaybeConvertible a e b => a -> b
unsafeConvert a =
    case tryConvert a of
      Left  e -> error $ show e
      Right r -> r

instance {-# OVERLAPPABLE #-} Convertible a a where
    convert = id

instance {-# OVERLAPPABLE #-} Convertible a b => Convertible (Maybe a) (Maybe b) where
    convert = fmap convert

instance {-# OVERLAPPABLE #-} Convertible a b => Castable a b where
    cast = convert

class ConvertibleM  m n where convertM  :: m (t1 :: k) -> n (t1 :: k)
class ConvertibleM2 m n where convertM2 :: m (t1 :: k) (t2 :: k) -> n (t1 :: k) (t2 :: k)
class ConvertibleM3 m n where convertM3 :: m (t1 :: k) (t2 :: k) (t3 :: k) -> n (t1 :: k) (t2 :: k) (t3 :: k)
class ConvertibleM4 m n where convertM4 :: m (t1 :: k) (t2 :: k) (t3 :: k) (t4 :: k) -> n (t1 :: k) (t2 :: k) (t3 :: k) (t4 :: k)
class ConvertibleM5 m n where convertM5 :: m (t1 :: k) (t2 :: k) (t3 :: k) (t4 :: k) (t5 :: k) -> n (t1 :: k) (t2 :: k) (t3 :: k) (t4 :: k) (t5 :: k)
