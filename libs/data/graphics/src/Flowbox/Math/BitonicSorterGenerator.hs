{-# LANGUAGE QuasiQuotes     #-}
{-# LANGUAGE TemplateHaskell #-}

module Flowbox.Math.BitonicSorterGenerator (generateBitonicNetworkList, generateBitonicNetworkTuple, generateGetNthFromTuple)  where

import           Control.Monad       (replicateM)
import           Language.Haskell.TH

import           Flowbox.Prelude     hiding ((<&>))

(<&>) = flip fmap

generateGetNthFromTuple :: Int -> Int -> Q Exp
generateGetNthFromTuple elem size = do
    name <- newName "x"
    let patternP = tupleGenerator $ (replicate elem wildP) ++ (varP name : replicate (size - elem - 1) wildP)
        expr = varE name
    lamE [patternP] expr

tupleGenerator [value] = tupP [value]
tupleGenerator (a:b:rest) = foldl tuple (tupP [a, b]) rest where
  tuple val new = tupP [val, new]

generateBitonicNetworkTuple :: Int -> Int -> Q Exp
generateBitonicNetworkTuple width height = do
    let size = width * height
    variables <- replicateM height (generateWires width)
    let mergedVariables = concat variables
    resultExpression <- generateSorter mergedVariables size
    let tuplesP = TupP $ (TupP . map VarP) <$> variables
    return $ LamE [tuplesP] resultExpression

generateBitonicNetworkList :: Int -> Q Exp
generateBitonicNetworkList size = do
    variables <- generateWires size
    resultExpresion <- generateSorter variables size
    let varsP = ListP $ VarP <$> variables
    return $ LamE [varsP] resultExpresion

generateSorter [inputWire] _ = tupE [varE inputWire]
generateSorter list@(_:_:rest) size = do
    let aSize = size `div` 2
        bSize = size - aSize
        (halfA, halfB) = splitAt aSize list
    sorterHalfA <- normalB $ generateSorter halfA aSize
    sorterHalfB <- normalB $ generateSorter halfB bSize
    [wireNamesA, wireNamesB] <- sequence $ generateWires <$> [aSize, bSize]
    merge <- generateMerger (reverse wireNamesA ++ wireNamesB) size
    let [wiresA, wiresB] = wiresGeneratorP <$> [wireNamesA, wireNamesB]
    return $ LetE [ValD wiresA sorterHalfA [], ValD wiresB sorterHalfB []] merge

generateMerger wires size =
    if size == 1
      then
        return $ wiresGeneratorE wires
      else
        generateMerger' wires size

generateMerger' wires size = do
    let split = splitOnPowerOf2 size
        aSize = split
        bSize = size - aSize
        (firstHalf, secondHalf) = splitAt split wires
    (newNames, decls) <- halfCleaner firstHalf aSize secondHalf bSize
    let (recFirstNames, recSecondNames) = splitAt split newNames
    firstHalfMerged <- normalB $ generateMerger recFirstNames aSize
    secondHalfMerged <- normalB $ generateMerger recSecondNames bSize
    recWires <- generateWires size
    let [resFirstWiresP, resSecondWiresP] = ((wiresGeneratorP .) <$> [fst, snd]) <&> ($ splitAt split recWires)
        resultE = wiresGeneratorE recWires
    return $ LetE decls $ LetE [ValD resFirstWiresP firstHalfMerged [], ValD resSecondWiresP secondHalfMerged []] resultE

halfCleaner wiresA sizeA wiresB sizeB = do
    newWireNamesA <- generateWires sizeA
    newWireNamesB <- generateWires sizeB
    declarations <- halfCleaner' newWireNamesA wiresA newWireNamesB wiresB
    declsRes <- if sizeA - sizeB > 0 then do
                    let missingNamesP = wiresGeneratorP $ drop sizeB newWireNamesA
                        missingValuesB = (NormalB . wiresGeneratorE) $ drop sizeB wiresA
                        missingDecls = ValD missingNamesP missingValuesB []
                    return $ missingDecls : declarations
                else return declarations
    return (newWireNamesA ++ newWireNamesB, declsRes)

halfCleaner' newWireNamesA wiresA newWireNamesB wiresB = mapM declaration declarationPairs where
  declarationPairs = zip (zip newWireNamesA newWireNamesB) (zip wiresA wiresB)

declaration ((nameA, nameB),(vA, vB)) = valD pat val [] where
  pat = return $ wiresGeneratorP [nameA, nameB]
  minMax = ['min,'max] <&> \method -> appE (appE (varE method) (varE vA)) (varE vB)
  val = normalB $ tupE minMax

splitOnPowerOf2 size = split' size 1 where
  split' a power | power < a = split' a $ power * 2
                 | power >= a = power `div` 2

wiresGeneratorP [name] = TupP [VarP name]
wiresGeneratorP (a:b:rest) = foldl tuple (TupP [VarP a, VarP b]) rest where
  tuple tupleVal name = TupP [tupleVal, VarP name]

wiresGeneratorE [name] = TupE [VarE name]
wiresGeneratorE (a:b:rest) = foldl tuple (TupE [VarE a, VarE b]) rest where
  tuple tupleVal name = TupE [tupleVal, VarE name]

generateWires size = replicateM size (newName "x")
