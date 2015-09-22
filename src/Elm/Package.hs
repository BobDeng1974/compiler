module Elm.Package where

import Control.Applicative ((<$>), (<*>))
import Data.Aeson
import Data.Binary
import qualified Data.Char as Char
import Data.Function (on)
import qualified Data.List as List
import qualified Data.Text as T
import System.FilePath ((</>))


-- PACKGE NAMES

data Name = Name
    { user :: String
    , project :: String
    }
    deriving (Eq, Ord, Show)


type Package = (Name, Version)


dummyName :: Name
dummyName =
    Name "USER" "PROJECT"


coreName :: Name
coreName =
  Name "elm-lang" "core"


toString :: Name -> String
toString name =
    user name ++ "/" ++ project name


toUrl :: Name -> String
toUrl name =
    user name ++ "/" ++ project name


toFilePath :: Name -> FilePath
toFilePath name =
    user name </> project name


fromString :: String -> Either String Name
fromString string =
    case break (=='/') string of
      ( user, '/' : project ) ->
          if null user then
              Left "You did not provide a user name (USER/PROJECT)"

          else if null project then
              Left "You did not provide a project name (USER/PROJECT)"

          else if all (/='/') project then
              Name user <$> validate project

          else
              Left "Expecting only one slash, separating the user and project name (USER/PROJECT)"

      _ ->
          Left "There should be a slash separating the user and project name (USER/PROJECT)"


validate :: String -> Either String String
validate str =
  if elem ('-','-') (zip str (tail str)) then
      Left "There is a double dash -- in your package name. It must be a single dash."

  else if elem '_' str then
      Left "Underscores are not allowed in package names."

  else if any Char.isUpper str then
      Left "Upper case characters are not allowed in package names."

  else if not (Char.isLetter (head str)) then
      Left "Package names must start with a letter."

  else
      Right str


instance Binary Name where
    get = Name <$> get <*> get
    put (Name user project) =
        do  put user
            put project


instance FromJSON Name where
    parseJSON (String text) =
        let
          string = T.unpack text
        in
          case fromString string of
            Left msg ->
                fail ("Ran into an invalid package name: " ++ string ++ "\n\n" ++ msg)

            Right name ->
                return name

    parseJSON _ =
        fail "Project name must be a string."


instance ToJSON Name where
    toJSON name =
        toJSON (toString name)


-- PACKAGE VERSIONS

data Version = Version
    { _major :: Int
    , _minor :: Int
    , _patch :: Int
    }
    deriving (Eq, Ord)


initialVersion :: Version
initialVersion =
    Version 1 0 0

dummyVersion :: Version
dummyVersion =
    Version 0 0 0


bumpPatch :: Version -> Version
bumpPatch (Version major minor patch) =
    Version major minor (patch + 1)

bumpMinor :: Version -> Version
bumpMinor (Version major minor _patch) =
    Version major (minor + 1) 0

bumpMajor :: Version -> Version
bumpMajor (Version major _minor _patch) =
    Version (major + 1) 0 0


-- FILTERING

filterLatest :: (Ord a) => (Version -> a) -> [Version] -> [Version]
filterLatest characteristic versions =
    map last (List.groupBy ((==) `on` characteristic) (List.sort versions))


majorAndMinor :: Version -> (Int,Int)
majorAndMinor (Version major minor _patch) =
    (major, minor)


-- CONVERSIONS

versionToString :: Version -> String
versionToString (Version major minor patch) =
    show major ++ "." ++ show minor ++ "." ++ show patch


versionFromString :: String -> Maybe Version
versionFromString string =
      case splitNumbers string of
        Just [major, minor, patch] ->
            Just (Version major minor patch)
        _ -> Nothing
    where
      splitNumbers :: String -> Maybe [Int]
      splitNumbers ns =
          case span Char.isDigit ns of
            ("", _) ->
                Nothing

            (numbers, []) ->
                Just [ read numbers ]

            (numbers, '.':rest) ->
                (read numbers :) <$> splitNumbers rest

            _ -> Nothing


instance Binary Version where
    get = Version <$> get <*> get <*> get
    put (Version major minor patch) =
        do put major
           put minor
           put patch


instance FromJSON Version where
    parseJSON (String text) =
        let string = T.unpack text in
        case versionFromString string of
          Just v -> return v
          Nothing ->
              fail $ unlines
                 [ "Dependency file has an invalid version number: " ++ string
                 , "Must have format MAJOR.MINOR.PATCH (e.g. 0.1.2)"
                 ]

    parseJSON _ =
        fail "Version number must be stored as a string."


instance ToJSON Version where
    toJSON version =
        toJSON (versionToString version)

