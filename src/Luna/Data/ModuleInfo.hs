---------------------------------------------------------------------------
---- Copyright (C) Flowbox, Inc - All Rights Reserved
---- Unauthorized copying of this file, via any medium is strictly prohibited
---- Proprietary and confidential
---- Flowbox Team <contact@flowbox.io>, 2015
-----------------------------------------------------------------------------

module Luna.Data.ModuleInfo where

import           Control.Monad           (foldM, liftM, (<=<), (>=>))
import           Data.Binary
import           Data.Either             (lefts, rights)
import qualified Data.IntMap             as IntMap
import           Data.List               (filter, find)
import           Data.Map                (Map)
import qualified Data.Map                as Map
import           Data.Maybe              (fromJust, fromMaybe, isJust)
import           Data.Text.Internal.Lazy (Text)
import qualified Data.Text.Lazy          as T
import qualified System.Directory        as Dir
import           System.Environment      (lookupEnv)
import           System.FilePath         (joinPath, (</>))

import           Data.Either.Combinators  (mapRight)
import           Flowbox.Data.MapForest   (Node)
import qualified Flowbox.Data.MapForest   as MF
import           Flowbox.Prelude
import           Flowbox.System.UniPath   (PathItem, UniPath, toUnixString)
import           Luna.Data.StructInfo     (OriginInfo, Scope, StructInfo)
import qualified Luna.Data.StructInfo     as SI
import           Luna.Syntax.AST          (ID)
import           Luna.Syntax.Decl         (Path)
import           Luna.Syntax.Name         (TName (TName), TNameP)
import           Luna.Syntax.Name.Path    (NamePath, QualPath (QualPath))
import qualified Luna.Syntax.Name.Path    as NP
import           Luna.Syntax.Name.Pattern (NamePatDesc, SegmentDesc)


type Name = String


data ImportError = NotFoundError { path :: QualPath }
                 | AmbRefError   { symbol :: NamePath, modules :: [QualPath] }
                 deriving (Generic, Eq, Show, Ord, Read)

makeLenses ''ImportError

-- stores the information about a module, needed while importing
-- and resolving names. Checking whether a file needs recompilation is done based on the file  edit dates
data ModuleInfo = ModuleInfo {
                     _name    :: QualPath,
--                     _symTable :: Map NamePath ID,
                     _imports :: [QualPath],
                     _strInfo :: StructInfo,  -- [?] Namespace here?
                     _errors  :: [ImportError]
                  } deriving (Generic, Eq, Show, Read)

makeLenses ''ModuleInfo


-- given a list of paths, lookups all the necessary ModuleInfo structs
getModuleInfos :: [QualPath] -> IO [Either ImportError ModuleInfo]
getModuleInfos = mapM getModuleInfo

getModuleInfo :: QualPath -> IO (Either ImportError ModuleInfo)
getModuleInfo path = readModInfoFromFile path >>= \case
    Just modInfo -> return $ Right modInfo
    Nothing      -> return $ Left (NotFoundError path)


regError :: ImportError -> ModuleInfo -> ModuleInfo
regError err = errors %~ (err:)


-- checks if the module exists (but not if it's parsed)
moduleExists :: QualPath -> IO Bool
moduleExists path = do
    f <- Dir.findFile [modPathToDirString path] (modName path ++ lunaFileSuffix)
    return $ isJust f


moduleNotExists :: QualPath -> IO Bool
moduleNotExists path = do
    f <- Dir.findFile [modPathToDirString path] (modName path ++ lunaFileSuffix)
    return . not . isJust $ f

-- checks if module is already parsed (i.e. the ModuleInfo is present)
moduleIsParsed :: QualPath -> IO Bool
moduleIsParsed path = do
    let fullPath = modPathToString path ++ liFileSuffix
    f      <- Dir.findFile [liDirectory] fullPath
    return $ isJust f


modPathToString :: QualPath -> String
modPathToString qp@(QualPath _ n) = modPathToDirString qp </> T.unpack n


-- the difference between this one and modPathToString is that
-- this returns the directory of the module, not the module name itself
modPathToDirString :: QualPath -> FilePath
modPathToDirString (QualPath ns _) = joinPath $ map T.unpack ns


modName :: QualPath -> String
modName qp = T.unpack $ qp ^. NP.name


pathToQualPath :: Path -> QualPath
pathToQualPath path = QualPath ns n
    where list = map toText path
          n    = last list
          ns   = init list

qualPathToPath :: QualPath -> Path
qualPathToPath (QualPath ns n) = segs ++ [seg]
    where segs = map makeTNameP ns
          seg  = (fromText n) :: TNameP
          makeTNameP = (\x -> fromText x) :: T.Text -> TNameP

--------------------------------------------------------------------------
-- ModuleInfo serialization utils
--------------------------------------------------------------------------
lunaFileSuffix :: FilePath
lunaFileSuffix = ".luna"

liFileSuffix :: FilePath
liFileSuffix = ".li"


liDirectory :: FilePath
liDirectory = "modinfo"


-- does the main serialization:
writeModInfoToFile :: ModuleInfo -> IO ()
writeModInfoToFile modInfo = do
    -- if the directory doesn't exist, create one:
    tmpDir <- Dir.getTemporaryDirectory
    let modDir = tmpDir </> liDirectory </> (modPathToDirString $ modInfo ^. name)
    Dir.createDirectoryIfMissing True modDir
    let mName = modName $ modInfo ^. name
        fPath = modDir </> mName ++ liFileSuffix
    -- serialize with Data.Binry:
    encodeFile fPath modInfo


-- deserialization:
readModInfoFromFile :: QualPath -> IO (Maybe ModuleInfo)
readModInfoFromFile path = do
    isParsed <- moduleIsParsed path
    if isParsed
        then do
            let modPath = liDirectory </> modPathToString path ++ liFileSuffix
            Just <$> decodeFile modPath
        else return Nothing


-----------------------------------------------------------------------------
-- instance declarations for serialization
-- they can be moved to a separate module, save ModuleInfo (that would cause cycle imports
-----------------------------------------------------------------------------

instance Binary ModuleInfo
instance Binary StructInfo
instance Binary OriginInfo
instance Binary Scope
instance Binary NamePatDesc
instance Binary SegmentDesc
instance Binary SI.Error
instance Binary ImportError
instance Binary (Node Text OriginInfo)


instance Monoid ModuleInfo where
    mempty      = ModuleInfo mempty mempty mempty mempty --mempty
    mappend a b = ModuleInfo (mappend (a ^. name)     (b ^. name))
                             --(mappend (a ^. symTable) (b ^. symTable))
                             (mappend (a ^. imports)  (b ^. imports))
                             (mappend (a ^. strInfo)  (b ^. strInfo))
                             (mappend (a ^. errors)   (b ^. errors))


instance Monoid QualPath where
    mempty      = QualPath [] mempty
    mappend     = const

