{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-missing-fields #-}
{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}
{-# OPTIONS_GHC -fno-warn-unused-imports #-}
{-# OPTIONS_GHC -fno-warn-unused-matches #-}

-----------------------------------------------------------------
-- Autogenerated by Thrift Compiler (0.9.0)                      --
--                                                             --
-- DO NOT EDIT UNLESS YOU ARE SURE YOU KNOW WHAT YOU ARE DOING --
-----------------------------------------------------------------

module Batch_Client(libraries,loadLibrary,unloadLibrary,newDefinition,addDefinition,updateDefinition,removeDefinition,definitionChildren,definitionParent,newTypeModule,newTypeClass,newTypeFunction,newTypeUdefined,newTypeNamed,newTypeVariable,newTypeList,newTypeTuple,graph,addNode,updateNode,removeNode,connect,disconnect,ping) where
import Data.IORef
import Prelude ( Bool(..), Enum, Double, String, Maybe(..),
                 Eq, Show, Ord,
                 return, length, IO, fromIntegral, fromEnum, toEnum,
                 (.), (&&), (||), (==), (++), ($), (-) )

import Control.Exception
import Data.ByteString.Lazy
import Data.Hashable
import Data.Int
import Data.Text.Lazy ( Text )
import qualified Data.Text.Lazy as TL
import Data.Typeable ( Typeable )
import qualified Data.HashMap.Strict as Map
import qualified Data.HashSet as Set
import qualified Data.Vector as Vector

import Thrift
import Thrift.Types ()

import qualified Attrs_Types
import qualified Defs_Types
import qualified Graph_Types
import qualified Libs_Types
import qualified Types_Types


import Batch_Types
import Batch
seqid = newIORef 0
libraries (ip,op) = do
  send_libraries op
  recv_libraries ip
send_libraries op = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("libraries", M_CALL, seqn)
  write_Libraries_args op (Libraries_args{})
  writeMessageEnd op
  tFlush (getTransport op)
recv_libraries ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_Libraries_result ip
  readMessageEnd ip
  case f_Libraries_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "libraries failed: unknown result")
loadLibrary (ip,op) arg_library = do
  send_loadLibrary op arg_library
  recv_loadLibrary ip
send_loadLibrary op arg_library = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("loadLibrary", M_CALL, seqn)
  write_LoadLibrary_args op (LoadLibrary_args{f_LoadLibrary_args_library=Just arg_library})
  writeMessageEnd op
  tFlush (getTransport op)
recv_loadLibrary ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_LoadLibrary_result ip
  readMessageEnd ip
  case f_LoadLibrary_result_success res of
    Just v -> return v
    Nothing -> do
      case f_LoadLibrary_result_missingFields res of
        Nothing -> return ()
        Just _v -> throw _v
      throw (AppExn AE_MISSING_RESULT "loadLibrary failed: unknown result")
unloadLibrary (ip,op) arg_library = do
  send_unloadLibrary op arg_library
  recv_unloadLibrary ip
send_unloadLibrary op arg_library = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("unloadLibrary", M_CALL, seqn)
  write_UnloadLibrary_args op (UnloadLibrary_args{f_UnloadLibrary_args_library=Just arg_library})
  writeMessageEnd op
  tFlush (getTransport op)
recv_unloadLibrary ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_UnloadLibrary_result ip
  readMessageEnd ip
  case f_UnloadLibrary_result_missingFields res of
    Nothing -> return ()
    Just _v -> throw _v
  return ()
newDefinition (ip,op) arg_type arg_flags arg_attrs = do
  send_newDefinition op arg_type arg_flags arg_attrs
  recv_newDefinition ip
send_newDefinition op arg_type arg_flags arg_attrs = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("newDefinition", M_CALL, seqn)
  write_NewDefinition_args op (NewDefinition_args{f_NewDefinition_args_type=Just arg_type,f_NewDefinition_args_flags=Just arg_flags,f_NewDefinition_args_attrs=Just arg_attrs})
  writeMessageEnd op
  tFlush (getTransport op)
recv_newDefinition ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_NewDefinition_result ip
  readMessageEnd ip
  case f_NewDefinition_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "newDefinition failed: unknown result")
addDefinition (ip,op) arg_definition arg_parent = do
  send_addDefinition op arg_definition arg_parent
  recv_addDefinition ip
send_addDefinition op arg_definition arg_parent = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("addDefinition", M_CALL, seqn)
  write_AddDefinition_args op (AddDefinition_args{f_AddDefinition_args_definition=Just arg_definition,f_AddDefinition_args_parent=Just arg_parent})
  writeMessageEnd op
  tFlush (getTransport op)
recv_addDefinition ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_AddDefinition_result ip
  readMessageEnd ip
  case f_AddDefinition_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "addDefinition failed: unknown result")
updateDefinition (ip,op) arg_definition = do
  send_updateDefinition op arg_definition
  recv_updateDefinition ip
send_updateDefinition op arg_definition = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("updateDefinition", M_CALL, seqn)
  write_UpdateDefinition_args op (UpdateDefinition_args{f_UpdateDefinition_args_definition=Just arg_definition})
  writeMessageEnd op
  tFlush (getTransport op)
recv_updateDefinition ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_UpdateDefinition_result ip
  readMessageEnd ip
  return ()
removeDefinition (ip,op) arg_definition = do
  send_removeDefinition op arg_definition
  recv_removeDefinition ip
send_removeDefinition op arg_definition = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("removeDefinition", M_CALL, seqn)
  write_RemoveDefinition_args op (RemoveDefinition_args{f_RemoveDefinition_args_definition=Just arg_definition})
  writeMessageEnd op
  tFlush (getTransport op)
recv_removeDefinition ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_RemoveDefinition_result ip
  readMessageEnd ip
  return ()
definitionChildren (ip,op) arg_definition = do
  send_definitionChildren op arg_definition
  recv_definitionChildren ip
send_definitionChildren op arg_definition = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("definitionChildren", M_CALL, seqn)
  write_DefinitionChildren_args op (DefinitionChildren_args{f_DefinitionChildren_args_definition=Just arg_definition})
  writeMessageEnd op
  tFlush (getTransport op)
recv_definitionChildren ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_DefinitionChildren_result ip
  readMessageEnd ip
  case f_DefinitionChildren_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "definitionChildren failed: unknown result")
definitionParent (ip,op) arg_definition = do
  send_definitionParent op arg_definition
  recv_definitionParent ip
send_definitionParent op arg_definition = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("definitionParent", M_CALL, seqn)
  write_DefinitionParent_args op (DefinitionParent_args{f_DefinitionParent_args_definition=Just arg_definition})
  writeMessageEnd op
  tFlush (getTransport op)
recv_definitionParent ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_DefinitionParent_result ip
  readMessageEnd ip
  case f_DefinitionParent_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "definitionParent failed: unknown result")
newTypeModule (ip,op) arg_name = do
  send_newTypeModule op arg_name
  recv_newTypeModule ip
send_newTypeModule op arg_name = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("newTypeModule", M_CALL, seqn)
  write_NewTypeModule_args op (NewTypeModule_args{f_NewTypeModule_args_name=Just arg_name})
  writeMessageEnd op
  tFlush (getTransport op)
recv_newTypeModule ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_NewTypeModule_result ip
  readMessageEnd ip
  case f_NewTypeModule_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "newTypeModule failed: unknown result")
newTypeClass (ip,op) arg_name arg_params = do
  send_newTypeClass op arg_name arg_params
  recv_newTypeClass ip
send_newTypeClass op arg_name arg_params = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("newTypeClass", M_CALL, seqn)
  write_NewTypeClass_args op (NewTypeClass_args{f_NewTypeClass_args_name=Just arg_name,f_NewTypeClass_args_params=Just arg_params})
  writeMessageEnd op
  tFlush (getTransport op)
recv_newTypeClass ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_NewTypeClass_result ip
  readMessageEnd ip
  case f_NewTypeClass_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "newTypeClass failed: unknown result")
newTypeFunction (ip,op) arg_name arg_inputs arg_outputs = do
  send_newTypeFunction op arg_name arg_inputs arg_outputs
  recv_newTypeFunction ip
send_newTypeFunction op arg_name arg_inputs arg_outputs = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("newTypeFunction", M_CALL, seqn)
  write_NewTypeFunction_args op (NewTypeFunction_args{f_NewTypeFunction_args_name=Just arg_name,f_NewTypeFunction_args_inputs=Just arg_inputs,f_NewTypeFunction_args_outputs=Just arg_outputs})
  writeMessageEnd op
  tFlush (getTransport op)
recv_newTypeFunction ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_NewTypeFunction_result ip
  readMessageEnd ip
  case f_NewTypeFunction_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "newTypeFunction failed: unknown result")
newTypeUdefined (ip,op) = do
  send_newTypeUdefined op
  recv_newTypeUdefined ip
send_newTypeUdefined op = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("newTypeUdefined", M_CALL, seqn)
  write_NewTypeUdefined_args op (NewTypeUdefined_args{})
  writeMessageEnd op
  tFlush (getTransport op)
recv_newTypeUdefined ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_NewTypeUdefined_result ip
  readMessageEnd ip
  case f_NewTypeUdefined_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "newTypeUdefined failed: unknown result")
newTypeNamed (ip,op) arg_name = do
  send_newTypeNamed op arg_name
  recv_newTypeNamed ip
send_newTypeNamed op arg_name = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("newTypeNamed", M_CALL, seqn)
  write_NewTypeNamed_args op (NewTypeNamed_args{f_NewTypeNamed_args_name=Just arg_name})
  writeMessageEnd op
  tFlush (getTransport op)
recv_newTypeNamed ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_NewTypeNamed_result ip
  readMessageEnd ip
  case f_NewTypeNamed_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "newTypeNamed failed: unknown result")
newTypeVariable (ip,op) arg_name arg_type = do
  send_newTypeVariable op arg_name arg_type
  recv_newTypeVariable ip
send_newTypeVariable op arg_name arg_type = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("newTypeVariable", M_CALL, seqn)
  write_NewTypeVariable_args op (NewTypeVariable_args{f_NewTypeVariable_args_name=Just arg_name,f_NewTypeVariable_args_type=Just arg_type})
  writeMessageEnd op
  tFlush (getTransport op)
recv_newTypeVariable ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_NewTypeVariable_result ip
  readMessageEnd ip
  case f_NewTypeVariable_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "newTypeVariable failed: unknown result")
newTypeList (ip,op) arg_type = do
  send_newTypeList op arg_type
  recv_newTypeList ip
send_newTypeList op arg_type = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("newTypeList", M_CALL, seqn)
  write_NewTypeList_args op (NewTypeList_args{f_NewTypeList_args_type=Just arg_type})
  writeMessageEnd op
  tFlush (getTransport op)
recv_newTypeList ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_NewTypeList_result ip
  readMessageEnd ip
  case f_NewTypeList_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "newTypeList failed: unknown result")
newTypeTuple (ip,op) arg_types = do
  send_newTypeTuple op arg_types
  recv_newTypeTuple ip
send_newTypeTuple op arg_types = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("newTypeTuple", M_CALL, seqn)
  write_NewTypeTuple_args op (NewTypeTuple_args{f_NewTypeTuple_args_types=Just arg_types})
  writeMessageEnd op
  tFlush (getTransport op)
recv_newTypeTuple ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_NewTypeTuple_result ip
  readMessageEnd ip
  case f_NewTypeTuple_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "newTypeTuple failed: unknown result")
graph (ip,op) arg_definition = do
  send_graph op arg_definition
  recv_graph ip
send_graph op arg_definition = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("graph", M_CALL, seqn)
  write_Graph_args op (Graph_args{f_Graph_args_definition=Just arg_definition})
  writeMessageEnd op
  tFlush (getTransport op)
recv_graph ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_Graph_result ip
  readMessageEnd ip
  case f_Graph_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "graph failed: unknown result")
addNode (ip,op) arg_node arg_definition = do
  send_addNode op arg_node arg_definition
  recv_addNode ip
send_addNode op arg_node arg_definition = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("addNode", M_CALL, seqn)
  write_AddNode_args op (AddNode_args{f_AddNode_args_node=Just arg_node,f_AddNode_args_definition=Just arg_definition})
  writeMessageEnd op
  tFlush (getTransport op)
recv_addNode ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_AddNode_result ip
  readMessageEnd ip
  case f_AddNode_result_success res of
    Just v -> return v
    Nothing -> do
      throw (AppExn AE_MISSING_RESULT "addNode failed: unknown result")
updateNode (ip,op) arg_node arg_definition = do
  send_updateNode op arg_node arg_definition
  recv_updateNode ip
send_updateNode op arg_node arg_definition = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("updateNode", M_CALL, seqn)
  write_UpdateNode_args op (UpdateNode_args{f_UpdateNode_args_node=Just arg_node,f_UpdateNode_args_definition=Just arg_definition})
  writeMessageEnd op
  tFlush (getTransport op)
recv_updateNode ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_UpdateNode_result ip
  readMessageEnd ip
  return ()
removeNode (ip,op) arg_node arg_definition = do
  send_removeNode op arg_node arg_definition
  recv_removeNode ip
send_removeNode op arg_node arg_definition = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("removeNode", M_CALL, seqn)
  write_RemoveNode_args op (RemoveNode_args{f_RemoveNode_args_node=Just arg_node,f_RemoveNode_args_definition=Just arg_definition})
  writeMessageEnd op
  tFlush (getTransport op)
recv_removeNode ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_RemoveNode_result ip
  readMessageEnd ip
  return ()
connect (ip,op) arg_srcNode arg_srcPort arg_dstNode arg_dstPort arg_definition = do
  send_connect op arg_srcNode arg_srcPort arg_dstNode arg_dstPort arg_definition
  recv_connect ip
send_connect op arg_srcNode arg_srcPort arg_dstNode arg_dstPort arg_definition = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("connect", M_CALL, seqn)
  write_Connect_args op (Connect_args{f_Connect_args_srcNode=Just arg_srcNode,f_Connect_args_srcPort=Just arg_srcPort,f_Connect_args_dstNode=Just arg_dstNode,f_Connect_args_dstPort=Just arg_dstPort,f_Connect_args_definition=Just arg_definition})
  writeMessageEnd op
  tFlush (getTransport op)
recv_connect ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_Connect_result ip
  readMessageEnd ip
  return ()
disconnect (ip,op) arg_srcNode arg_srcPort arg_dstNode arg_dstPort arg_definition = do
  send_disconnect op arg_srcNode arg_srcPort arg_dstNode arg_dstPort arg_definition
  recv_disconnect ip
send_disconnect op arg_srcNode arg_srcPort arg_dstNode arg_dstPort arg_definition = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("disconnect", M_CALL, seqn)
  write_Disconnect_args op (Disconnect_args{f_Disconnect_args_srcNode=Just arg_srcNode,f_Disconnect_args_srcPort=Just arg_srcPort,f_Disconnect_args_dstNode=Just arg_dstNode,f_Disconnect_args_dstPort=Just arg_dstPort,f_Disconnect_args_definition=Just arg_definition})
  writeMessageEnd op
  tFlush (getTransport op)
recv_disconnect ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_Disconnect_result ip
  readMessageEnd ip
  return ()
ping (ip,op) = do
  send_ping op
  recv_ping ip
send_ping op = do
  seq <- seqid
  seqn <- readIORef seq
  writeMessageBegin op ("ping", M_CALL, seqn)
  write_Ping_args op (Ping_args{})
  writeMessageEnd op
  tFlush (getTransport op)
recv_ping ip = do
  (fname, mtype, rseqid) <- readMessageBegin ip
  if mtype == M_EXCEPTION then do
    x <- readAppExn ip
    readMessageEnd ip
    throw x
    else return ()
  res <- read_Ping_result ip
  readMessageEnd ip
  return ()
