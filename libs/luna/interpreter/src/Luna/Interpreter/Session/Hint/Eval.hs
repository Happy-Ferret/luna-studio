---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Flowbox Team <contact@flowbox.io>, 2014
-- Proprietary and confidential
-- Unauthorized copying of this file, via any medium is strictly prohibited
---------------------------------------------------------------------------
{-# LANGUAGE MagicHash       #-}
{-# LANGUAGE TemplateHaskell #-}

module Luna.Interpreter.Session.Hint.Eval where

import qualified Data.Typeable as Typeable
import qualified GHC
import qualified GHC.Exts      as Exts

import           Flowbox.Prelude
import           Flowbox.System.Log.Logger
import qualified Luna.Interpreter.Session.Hint.Util as Util



logger :: LoggerIO
logger = getLoggerIO $(moduleName)


interpret :: (GHC.GhcMonad m, Typeable a) => String -> m a
interpret expr = interpret' expr wit where
    wit :: a
    wit = undefined


-- | Evaluates an expression, given a witness for its monomorphic type.
interpret' :: (GHC.GhcMonad m, Typeable a) => String -> a -> m a
interpret' expr wit = interpret'' expr typeStr where
    typeStr = show $ Typeable.typeOf wit


interpret'' :: (GHC.GhcMonad m, Typeable a) => String -> String -> m a
interpret'' expr typeStr = do
    let typedExpr = concat [parens expr, " :: ", typeStr]
    logger trace typedExpr
    exprVal <- GHC.compileExpr typedExpr
    return (Exts.unsafeCoerce# exprVal :: a)

-- | Conceptually, @parens s = \"(\" ++ s ++ \")\"@, where s is any valid haskell
-- expression. In practice, it is harder than this.
-- Observe that if @s@ ends with a trailing comment, then @parens s@ would
-- be a malformed expression. The straightforward solution for this is to
-- put the closing parenthesis in a different line. However, now we are
-- messing with the layout rules and we don't know where @s@ is going to
-- be used!
-- Solution: @parens s = \"(let {foo =\n\" ++ s ++ \"\\n ;} in foo)\"@ where @foo@ does not occur in @s@
parens :: String -> String
parens s = concat ["(let {", foo, " =\n", s, "\n",
                    "                     ;} in ", foo, ")"]
    where foo = Util.safeBndFor s
