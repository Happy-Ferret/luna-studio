---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

{-# LANGUAGE MultiParamTypeClasses #-}


module Luna.DEP.AST.Prop where

import Flowbox.Prelude


class HasName a where
    name :: a -> String