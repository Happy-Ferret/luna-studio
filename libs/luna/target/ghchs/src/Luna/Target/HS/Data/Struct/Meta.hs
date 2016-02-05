---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

{-# LANGUAGE DeriveDataTypeable    #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE GADTs                 #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE PolyKinds             #-}
{-# LANGUAGE UndecidableInstances  #-}


module Luna.Target.HS.Data.Struct.Meta {-# DEPRECATED "Not used anymore" #-} where

import           Data.Typeable
import           Type.BaseType

----------------------------------------------------------------------------------
-- Data types
----------------------------------------------------------------------------------

data Meta typeName = Meta (Proxy typeName) deriving (Show, Eq, Typeable)
meta = Meta Proxy


----------------------------------------------------------------------------------
-- Instances
----------------------------------------------------------------------------------

instance  out~(Proxy (Meta a)) =>BaseType (Proxy (Meta a)) out  where
    baseType = id
