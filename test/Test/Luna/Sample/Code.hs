---------------------------------------------------------------------------
-- Copyright (C) Flowbox, Inc - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited
-- Proprietary and confidential
-- Flowbox Team <contact@flowbox.io>, 2014
---------------------------------------------------------------------------
{-# LANGUAGE QuasiQuotes #-}

module Test.Luna.Sample.Code where

import Text.RawString.QQ

import           Flowbox.Prelude
import           Luna.AST.Control.Crumb                (Breadcrumbs)
import qualified Luna.AST.Control.Crumb                as Crumb
import           Test.Luna.Pass.Transform.Graph.Common (named)



type Name = String
type Code = String


sampleCodes :: [(Name, Code)]
sampleCodes = singleFun ++ manyFun


singleFun :: [(Name, Code)]
singleFun = [named "empty" [r|
def main
|], named "simple return" [r|
def main:
    1
|], named "simple infix" [r|
def main:
    1.+ 2
|], named "simple assignment 1" [r|
def main:
    x = 0
|], named "simple assignment 3" [r|
def main:
    x = 0
    {y, _} = x
|], named "simple assignment 4" [r|
def main:
    x = 0
    y = 1
    {z, v} = {x, y}
|], named "simple assignment 5" [r|
def main:
    x = 0
    y = 1
    {z, v} = {x, y}
    h = {z, v}
|], named "assignment with patterns" [r|
def main:
    x = 0
    y = 1
    {z, v} = {x, y}
    h = {z, v}
|], named "accessors 2" [r|
def main arg:
    arg.bar.baz
    2
|], named "accessors 5" [r|
def main arg:
    x = 4
    x.zooo 43
|], named "ranges" [r|
def main arg:
    x = {1, [1..10], [9..]}
|], named "constructors 1" [r|
def main arg:
    Main.foo 1 2 3
|], named "constructors 2" [r|
def main arg:
    Foo 1 2 3
|], named "constructors 3" [r|
def main arg:
    Foo arg.boo 1
|], named "tuples 1" [r|
def main arg:
    {1, 2}
    3
|], named "tuples 2" [r|
def main arg:
    x = 4
    y = {1, x}
|], named "lists" [r|
def main arg:
    x = 4
    y = [1, x]
|], named "native code" [r|
def main arg:
    ```autoLift1 print #{arg}```
|]]

manyFun :: [(Name, Code)]
manyFun = [named "simple assignment 2" [r|
def print

def main:
    x = 0
    y = x
    print y
|], named "assignment" [r|
def foo

def main arg1 arg2:
    tuple = self.mkTuple arg1 arg2
    self.foo tuple
    tuple
|], named "simple infix 2" [r|
def main:
    1 + 2
|], named "following calls" [r|
def foo
def bar

def main:
    1 + 2
    foo
    bar
|], named "following calls 2" [r|
def foo

def main:
    foo
    2
|], named "accessors 1" [r|
def foo

def main:
    foo.bar.baz
    2
|], named "accessors 3" [r|
def x

def main arg:
    x.zooo 43
    -2
|], named "accessors 4" [r|
def x

def main arg:
    x
    x.y
    x.z
|], named "accessors 6" [r|
def foo

def main arg:
    foo.bar
|], named "accessors and assignment" [r|
def foo

def main:
    x = foo.bar.baz
    2
|], named "accessors and apps 1" [r|
def foo

def main arg:
    foo.bar arg
    2
|], named "accessors and apps 2" [r|
def foo

def main arg:
    foo.bar arg 2
|], named "complicated inline calls" [r|
def foo

def main arg:
    x = foo.bar(arg, 15, arg, [19..]).baz arg 2
|], named "prints" [r|
def print

def main arg arg2:
    print arg
    print arg2
    self.bla "kota" "albo nie"
|], named "constructors 4" [r|
def gap

def main arg:
    Foo arg.boo My gap
|]]

---------------------------------------------------------------------------
---- DOES NOT WORK YET: ---------------------------------------------------
---------------------------------------------------------------------------

-- |], named "if-else" [r|
-- def print
--
-- def main arg:
--     print $ if 1 > 2: 5
--             else: 6
--     print $ 1 > 2


sampleLambdas :: [(Name, Breadcrumbs, Code)]
sampleLambdas = [
    ( "simple lambda"
    , [Crumb.Module "Main", Crumb.Function "main" [], Crumb.Lambda 6]
    , [r|
def main:
    f = a : a + 1
|]), ( "lambda with context"
    , [Crumb.Module "Main", Crumb.Function "main" [], Crumb.Lambda 12]
    , [r|
def main arg:
    x = 15
    f = a : a + 1 + x + arg
|])
    ]


emptyMain :: Code
emptyMain = "def main"


zipperTestModule :: Code
zipperTestModule = [r|
class Vector a:
    x,y,z :: a

    def test a b:
        {a,b, c : c + a + b}

    class Inner:
        def inner a b:
            a + b

def main:
    v = Vector 1 2 3
    v.test
|]
