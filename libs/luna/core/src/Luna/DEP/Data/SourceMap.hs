---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

module Luna.DEP.Data.SourceMap (
    module Luna.DEP.Data.SourceMap,
    module Data.Map
)where

import Data.Map

import Luna.DEP.AST.Common     (ID)
import Luna.DEP.Data.SourcePos (SourceRange)


type SourceMap = Map ID SourceRange

