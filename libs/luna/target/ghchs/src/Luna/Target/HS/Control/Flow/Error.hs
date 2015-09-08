---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------

{-# LANGUAGE NoMonomorphismRestriction #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE UndecidableInstances #-}



module Luna.Target.HS.Control.Flow.Error (
    module Luna.Target.HS.Control.Flow.Error,
    module X
) where

import Luna.Target.HS.Control.Error   as X
import Luna.Target.HS.Control.Context

----------------------------------------------------------------------------------
-- Instances
----------------------------------------------------------------------------------

-- FIXME [wd]: update
--instance  Catch e (base1 a1) (base2 a2) (base3 a3) =>Catch e (Value base1 a1) (Value base2 a2) (Value base3 a3)  where
--    catch f a = Value $ catch (fromValue . f) (fromValue a)

instance  Catch e a1 a2 a3 =>Catch e (Pure a1) (Pure a2) (Pure a3)  where
    catch f a = Pure $ catch (fromPure . f) (fromPure a)

-- FIXME [wd]: update
--instance  (Raise e a a', Functor base) =>Raise e (Value base a) (Value base a')  where
--    raise = fmap . raise

-- FIXME: we need other instances for catching here! For IO and MonadCtx