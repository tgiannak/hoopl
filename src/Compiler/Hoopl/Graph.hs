{-# LANGUAGE GADTs, EmptyDataDecls #-}

module Compiler.Hoopl.Graph 
  ( O, C, Block(..), Body, Body'(..), bodyMap, Graph, Graph'(..), MaybeO(..)
  , Edges(entryLabel, successors)
  , addBlock, bodyList
  )
where

import Compiler.Hoopl.Label

-----------------------------------------------------------------------------
--		Graphs
-----------------------------------------------------------------------------

data O
data C

data Block n e x where
  -- nodes
  ZFirst  :: n C O                 -> Block n C O
  ZMiddle :: n O O                 -> Block n O O
  ZLast   :: n O C                 -> Block n O C

  -- concatenation operations
  ZCat    :: Block n O O -> Block n O O -> Block n O O -- non-list-like
  ZHead   :: Block n C O -> n O O       -> Block n C O
  ZTail   :: n O O       -> Block n O C -> Block n O C  

  ZClosed :: Block n C O -> Block n O C -> Block n C C -- the zipper

type Body = Body' Block
data Body' block n where
  BodyEmpty :: Body' block n
  BodyUnit  :: block n C C -> Body' block n
  BodyCat   :: Body' block n -> Body' block n -> Body' block n

type Graph = Graph' Block
data Graph' block n e x where
  GNil  :: Graph' block n O O
  GUnit :: block n O O -> Graph' block n O O
  GMany :: MaybeO e (block n O C) 
        -> Body' block n
        -> MaybeO x (block n C O)
        -> Graph' block n e x

data MaybeO ex t where
  JustO    :: t -> MaybeO O t
  NothingO ::      MaybeO C t

instance Functor (MaybeO ex) where
  fmap _ NothingO = NothingO
  fmap f (JustO a) = JustO (f a)

-------------------------------
class Edges thing where
  entryLabel :: thing C x -> Label
  successors :: thing e C -> [Label]

instance Edges n => Edges (Block n) where
  entryLabel (ZFirst n)    = entryLabel n
  entryLabel (ZHead h _)   = entryLabel h
  entryLabel (ZClosed h _) = entryLabel h
  successors (ZLast n)     = successors n
  successors (ZTail _ t)   = successors t
  successors (ZClosed _ t) = successors t

------------------------------
addBlock :: block n C C -> Body' block n -> Body' block n
addBlock b body = BodyUnit b `BodyCat` body

bodyList :: Edges (block n) => Body' block n -> [(Label,block n C C)]
bodyList body = go body []
  where
    go BodyEmpty       bs = bs
    go (BodyUnit b)    bs = (entryLabel b, b) : bs
    go (BodyCat b1 b2) bs = go b1 (go b2 bs)

bodyMap :: Edges (block n) => Body' block n -> LabelMap (block n C C)
bodyMap = mkFactBase . bodyList

