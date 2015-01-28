---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE TemplateHaskell #-}

module Luna.Syntax.Graph.View.EdgeView where

import           Flowbox.Prelude
import           Luna.Syntax.Graph.Edge                (Edge)
import qualified Luna.Syntax.Graph.Edge                as Edge
import qualified Luna.Syntax.Graph.Port                as Port
import           Luna.Syntax.Graph.View.PortDescriptor (PortDescriptor)



data EdgeView = EdgeView { _src :: PortDescriptor
                         , _dst :: PortDescriptor
                         } deriving (Show, Read, Ord, Eq)


makeLenses(''EdgeView)

fromEdge :: Edge -> Maybe EdgeView
fromEdge (Edge.Monadic ) = Nothing
fromEdge (Edge.Data s d) = Just $ EdgeView (Port.toList s) (Port.toList d)
