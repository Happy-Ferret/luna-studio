---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Flowbox.Data.List (
    module List,
    module Flowbox.Data.List,
) where

import           Data.List       as List
import qualified Data.List.Utils as Utils

import           Flowbox.Prelude hiding (from, to)



foldri :: (a -> b -> b) -> [a] -> b -> b
foldri a b c = foldr a c b

foldli :: (a -> b -> a) -> [b] -> a -> a
foldli a b c = foldl a c b

--foldli :: (a -> b -> b) -> [a] -> b -> b
--foldli a b c = foldr a c b

count :: (a -> Bool) -> [a] -> Int
count predicate = length . List.filter predicate


merge :: (a -> a -> b) -> [a] -> [b]
merge _   []    = []
merge _   [_]   = []
merge fun (h:t) = fun h (head t) : merge fun t


stripIdx :: Int -> Int -> [a] -> [a]
stripIdx start end = reverse . drop end . reverse . drop start


replaceByMany :: Eq a => [a] -> [[a]] -> [a] -> [a]
replaceByMany _    []    = id
replaceByMany from (to:rest) = replaceByMany from rest . Utils.replace from to


insertAt :: Int -> a -> [a] -> [a]
insertAt 0 a l = a:l
insertAt i a [] = [a]
insertAt i a (h:t) = h:(insertAt (i-1) a t)


deleteAt :: Int -> [a] -> [a]
deleteAt _ []    = []
deleteAt 0 (_:t) = t
deleteAt i (h:t) = h:(deleteAt (i-1) t)
