---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE ViewPatterns #-}

module Flowbox.Data.MapTree where

import qualified Data.Map as Map

import Flowbox.Prelude



data MapTree name value = MapTree  { channel  :: Maybe value
                                   , children :: Map.Map name (MapTree name value)
                                   }
                        | EmptyNode
                        deriving (Show)
--makeLenses ''MapTree

data Crumb name value = Crumb name (Maybe value) (Map.Map name (MapTree name value))
                      | Snapshot (MapTree name value)
                      deriving (Show)

type Breadcrumbs name value = [Crumb name value]
type Zipper name value = (MapTree name value, Breadcrumbs name value)
type ZipperResult name value = Either ZipperError (Zipper name value)

data ZipperError = UnreachableError
                 | UpUnreachableError
                 | AttachToEmpty
                 | AppendToEmpty
                 | InsertToExisting
                 | AlterEmptyError
                 | RemoveEmptyError
                 | GetNonExistant
                 | SnapshotEmptyError
                 | PasteToExisting
                 | PasteWithoutCopy
                 deriving (Show, Eq)

-- == Instances ==

instance Functor (MapTree name) where
    fmap _ EmptyNode = EmptyNode
    fmap f (MapTree chan nodes) = MapTree (fmap f chan) $ (fmap . fmap) f nodes

-- == Tree ==

empty :: Ord name => MapTree name value
empty = MapTree Nothing mempty

-- == Traversing ==

zipper :: MapTree name value -> ZipperResult name value
zipper t = return (t, [])

tree :: Zipper name value -> MapTree name value
tree (t, _) = t

lookup :: (Show name, Show value, Ord name) => name -> Zipper name value -> ZipperResult name value
lookup _ (EmptyNode, _) = Left UnreachableError
lookup name (MapTree chan t, bs) = case Map.lookup name t of
    Nothing -> Left UnreachableError
    Just t' -> Right (t', Crumb name chan rest:bs)
    where rest = Map.delete name t

up :: Ord name => Zipper name value -> ZipperResult name value
up (_, [])             = Left UpUnreachableError
up (_, Snapshot _ : _) = Left UpUnreachableError
up (t, Crumb name chan rest:bs) = case t of
    EmptyNode -> Right (MapTree chan rest, bs)
    node      -> Right (MapTree chan (Map.insert name node rest), bs)

top :: Ord name => Zipper name value -> ZipperResult name value
top z = return $ top' z

top' :: Ord name => Zipper name value -> Zipper name value
top' z = case up z of
    Left  _ -> z
    Right u -> top' u

-- == Modifications ==

-- = Tree =

attach :: Ord name => name -> MapTree name value -> Zipper name value -> ZipperResult name value
attach name new (t, bs) = case t of
    EmptyNode       -> Left AttachToEmpty
    MapTree chan t' -> Right (MapTree chan (Map.insert name new t'), bs)

insert :: Ord name => Maybe value -> Zipper name value -> ZipperResult name value
insert v (t, bs) = case t of
    EmptyNode -> Right (MapTree v mempty, bs)
    _         -> Left InsertToExisting

append :: Ord name => name -> Maybe value -> Zipper name value -> ZipperResult name value
append name v = attach name (MapTree v mempty)

delete :: Zipper name value -> ZipperResult name value
delete (t, bs) = case t of
    EmptyNode   -> Left RemoveEmptyError
    MapTree _ _ -> Right (EmptyNode, bs)

-- = Copy Cut Paste =

copy :: Zipper name value -> ZipperResult name value
copy (EmptyNode, _) = Left SnapshotEmptyError
copy (t, bs)        = Right (t, bs ++ [Snapshot t]) -- order is important here

cut :: Zipper name value -> ZipperResult name value
cut x = copy x >>= delete

paste :: Zipper name value -> ZipperResult name value
paste (_, [])                               = Left PasteWithoutCopy
paste (EmptyNode, bs@(last -> Snapshot st)) = Right (st, init bs)
paste (EmptyNode, _)                        = Left PasteWithoutCopy
paste (_, _)                                = Left PasteToExisting

-- = Value =

clear :: Zipper name value -> ZipperResult name value
clear (t, bs) = case t of
    EmptyNode    -> Left AlterEmptyError
    MapTree _ t' -> Right (MapTree Nothing t', bs)

set :: value -> Zipper name value -> ZipperResult name value
set v (t, bs) = case t of
    EmptyNode    -> Left AlterEmptyError
    MapTree _ t' -> Right (MapTree (Just v) t', bs)

modify :: (value -> value) -> Zipper name value -> ZipperResult name value
modify f (t, bs) = case t of
    EmptyNode       -> Left AlterEmptyError
    MapTree chan t' -> Right (MapTree (fmap f chan) t', bs)

get :: Zipper name value -> Either ZipperError (Maybe value)
get (EmptyNode, _)     = Left GetNonExistant
get (MapTree val _, _) = Right val
