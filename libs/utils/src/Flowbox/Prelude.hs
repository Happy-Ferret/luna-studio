---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# LANGUAGE FlexibleContexts          #-}
{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE MultiParamTypeClasses #-}

module Flowbox.Prelude(
    module Flowbox.Prelude,
    module Prelude,
    module X
) where

import           Control.Applicative       as X
import           Control.Lens              as X
import           Data.Default              as X
import           GHC.Generics              as X (Generic)
import           Data.String.Repr          as X (StrRepr, strRepr)
import           Control.Monad.IO.Class    as X (MonadIO, liftIO)
import           Data.String.Class         as X (ToString(toString), IsString(fromString))
import           Data.Monoid               as X (Monoid, mempty, mappend, mconcat, (<>))
import           GHC.Exts                  as X (IsList, Item, fromList, fromListN, toList)
import           Data.Wrapper              as X (Wrap(wrap), Unwrap(unwrap), WrapT(wrapT), UnwrapT(unwrapT), Wrapper, WrapperT, rewrap)
import           Data.Convertible          as X (Convertible(safeConvert), convert)
import           Data.Text.Class           as X (ToText(toText), FromText(fromText), IsText)
import           Data.Text.Lazy            as X (Text)
import           Data.Foldable             as X (Foldable, traverse_)
import           Data.Typeable             as X (Typeable)
import           Control.Monad             as X (MonadPlus, mplus, mzero, unless, void, when)
import           Control.Monad.Trans       as X (MonadTrans, lift)
import           Data.Convertible.Instances.Missing as X
import           Data.Default.Instances.Missing ()
import           Data.Foldable             (forM_)
import qualified Data.Traversable          as Traversable
import           Text.Show.Pretty          (ppShow)
import           Data.List                 (intersperse)
import           Prelude hiding (mapM, mapM_, print, putStr, putStrLn, (++), (.))
import qualified Prelude



(++) :: Monoid a => a -> a -> a
(++) = mappend

print :: (MonadIO m, Show s) => s -> m ()
print    = liftIO . Prelude.print

printLn :: MonadIO m => m ()
printLn = putStrLn ""

putStr :: MonadIO m => String -> m ()
putStr   = liftIO . Prelude.putStr

putStrLn :: MonadIO m => String -> m ()
putStrLn = liftIO . Prelude.putStrLn

prettyPrint :: (MonadIO m, Show s) => s -> m ()
prettyPrint = putStrLn . ppShow

--instance (Typeable a) => Show (IO a) where
--    show e = '(' : (show . typeOf) e ++ ")"

--instance (Typeable a, Typeable b) => Show (a -> b) where
--    show e = '(' : (show . typeOf) e ++ ")"

-- f .: g = \x y->f (g x y)
-- f .: g = (f .) . g
-- (.:) f = ((f .) .)
-- (.:) = (.) (.) (.)
infixr 9 .
(.) :: (Functor f) => (a -> b) -> f a -> f b
(.) = fmap

(.:)  :: (x -> y) -> (a -> b -> x) -> a -> b -> y
(.:)   = (.) . (.)

(.:.) :: (x -> y) -> (a -> b -> c -> x) -> a -> b -> c -> y
(.:.)  = (.) . (.) . (.)

(.::) :: (x -> y) -> (a -> b -> c -> d -> x) -> a -> b -> c -> d -> y
(.::)  = (.) . (.) . (.) . (.)

mapM :: (Monad m, Traversable t) => (a -> m b) -> t a -> m (t b)
mapM = Traversable.mapM

mapM_ :: (Monad m, Traversable t) => (a -> m b) -> t a -> m ()
mapM_ f as = do
    _ <- mapM f as
    return ()


isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft _        = False

isRight :: Either a b -> Bool
isRight (Right _) = True
isRight _         = False


fromJustM :: Monad m => Maybe a -> m a
fromJustM Nothing  = fail "Prelude.fromJustM: Nothing"
fromJustM (Just x) = return x


whenLeft :: (Monad m) => Either a b -> (a -> m ()) -> m ()
whenLeft e f = case e of
    Left  v -> f v
    Right _ -> return ()


whenLeft' :: (Monad m) => Either a b -> m () -> m ()
whenLeft' e f = whenLeft e (const f)


whenRight :: (Monad m) => Either a b -> (b -> m ()) -> m ()
whenRight e f = case e of
    Left  _ -> return ()
    Right v -> f v


whenRight' :: (Monad m) => Either a b -> m () -> m ()
whenRight' e f = whenRight e $ const f

-- trenary operator
data Cond a = a :? a

infixl 0 ?
infixl 1 :?

(?) :: Bool -> Cond a -> a
True  ? (x :? _) = x
False ? (_ :? y) = y
-- / trenaru operator


($>) :: (Functor f) => a -> f b -> f b
($>) =  fmap . flip const


withJust :: Monad m => Maybe a -> (a -> m ()) -> m ()
withJust = forM_


lift2 :: (Monad (t1 m), Monad m,
          MonadTrans t, MonadTrans t1)
      => m a -> t (t1 m) a
lift2 = lift . lift


lift3 :: (Monad (t1 (t2 m)), Monad (t2 m), Monad m,
          MonadTrans t, MonadTrans t1, MonadTrans t2)
      => m a -> t (t1 (t2 m)) a
lift3 = lift . lift2


ifM :: Monad m => m Bool -> m a -> m a -> m a
ifM predicate a b = do bool <- predicate
                       if bool then a else b

whenM :: Monad m => m Bool -> m () -> m ()
whenM predicate a = do
    bool <- predicate
    when bool a


unlessM :: Monad m => m Bool -> m () -> m ()
unlessM predicate a = do
    bool <- predicate
    unless bool a


mjoin :: Monoid a => a -> [a] -> a
mjoin delim l = mconcat (intersperse delim l)


show' :: (Show a, IsString s) => a -> s
show' = fromString . Prelude.show

foldlDef :: (a -> a -> a) -> a -> [a] -> a
foldlDef f d = \case
    []     -> d
    (x:xs) -> foldl f x xs