---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE UndecidableInstances #-}

module Luna.ASTNew.Module where

import GHC.Generics      (Generic)
import Flowbox.Prelude

import Luna.ASTNew.Name  (TName)
import Luna.ASTNew.Decl  (LDecl)
import Luna.ASTNew.Label (Label)
import Luna.ASTNew.Name.Path (QualPath)


data Module a e = Module { _mpath :: QualPath
                         , _body  :: [LDecl a e]
                         } deriving (Show, Eq, Generic, Read)


type LModule a e = Label a (Module a e)