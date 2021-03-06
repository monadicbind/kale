module KaleSpec where

import Test.Hspec

import Kale

spec :: Spec
spec = do
    describe "driver" $ do
        it "is empty on empty tasks" $
            unDriver (driver []) `shouldBe` ""
        it "has command sum" $
            unDriver (driver [Task (TaskModule "Foo.Bar") NoArgs (TaskName "Bar")])
                `shouldBe` unlines
                    [ "kaleMain :: IO ()"
                    , "kaleMain = do"
                    , "  cmd <- getRecord \"kale-discovery\""
                    , "  case (cmd :: Command) of"
                    , "    Bar -> Foo.BarTask.task"
                    ]

    describe "casify" $ do
        it "simple case works" $
            casify "HelloWorld" `shouldBe` TaskName "Hello_World"
        it "acts strange with many caps letters" $
            casify "HTTPWorker" `shouldBe` TaskName "H_T_T_P_Worker"
        -- the inputs to casify will always be module names, so the below should
        -- not happen
        it "acts strange with initial lowercase" $
            casify "lowHigh" `shouldBe` TaskName "l_o_w_High"

    describe "decs" $ do
        it "roughly parses declarations" $ do
            decs decs1
                `shouldBe`
                    [ "data Foo = Bar"
                    ]
            decs decs0
                `shouldBe`
                    [ "module Foo where"
                    , "import Asdf"
                    , "data Foo = Bar | Baz"
                    ]
        it "can parse record syntax" $
            decs decs2
                `shouldBe`
                    [ "module Wat where"
                    , "data Foo = Foo { fooName :: String , fooAge :: Int }"
                    ]

        it "can parse weird records" $
            decs decs3
                `shouldBe`
                    [ "data Foo = Foo { fooName :: String}"
                    ]

    describe "mkCommandSum" $ do
        it "is empty on empty task lists" $
            unCommandSumType (mkCommandSum []) `shouldBe` ""
        it "lists tasktnames properly" $
            unCommandSumType (mkCommandSum [task0, task1, task2])
                `shouldBe` concat
                    [ "data Command = Name { foo :: Int }"
                    , " | Other_Name | Yes_Name Int (Maybe String) deriving (Eq, "
                    , "Show, Read, Generic, ParseRecord)"
                    ]

    describe "taskToSum" $ do
        it "works with positional arguments" $ do
            taskToSum task2
                `shouldBe`
                    "Yes_Name Int (Maybe String)"

    describe "mkCaseOf" $ do
        it "works with args" $ do
            mkCaseOf task0
                `shouldBe`
                    "Name {..} -> Module.FooTask.task Module.FooTask.Args {..}"
        it "works without args" $ do
            mkCaseOf task1
                `shouldBe`
                    "Other_Name -> Module1.FooTask.task"
        it "works with positional args" $ do
            mkCaseOf task2
                `shouldBe`
                    "Yes_Name arg0 arg1 -> Module1.BarTask.task (Module1.BarTask.Args arg0 arg1)"

    describe "mkCaseMatch" $ do
        it "works on record arguments" $ do
            mkCaseMatch task0 `shouldBe` "{..}"
        it "works on empty arguments" $ do
            mkCaseMatch task1 `shouldBe` ""
        it "works on positional arguments" $ do
            mkCaseMatch task2 `shouldBe` "arg0 arg1"

    describe "mkTaskArgs" $ do
        it "successfully determines no arguments" $ do
            mkTaskArgs (FileContent "module Foo where\n\ntask :: IO ()")
                `shouldBe`
                    NoArgs

        it "successfully determines record args" $ do
            mkTaskArgs (FileContent "data Args = Args { foo :: Int }")
                `shouldBe`
                    RecordArgs "{ foo :: Int }"

        it "succeeds on positional args" $ do
            mkTaskArgs (FileContent "data Args = Args Int String")
                `shouldBe`
                    PositionalArgs ["Int", "String"]


    describe "mkTask" $ do
        it "is Nothing for taskArgs when fileContent is empty" $
            mkTask (FileContent "") (TaskName "Other_Name") (TaskModule "Module1.Foo") `shouldBe` task1

    describe "pathToModule" $ do
        it "parses directories and file extensions" $
            pathToModule "foo/bar.baz" == "Bar" `shouldBe` True

    describe "importList" $ do
        it "pulls out taskModules and splits into newlines" $
            unImportList (importList [task0, task1]) `shouldBe`
                unlines [
                        "import qualified Module.FooTask",
                        "import qualified Module1.FooTask"
                        ]

    describe "findArgs" $ do
        it "finds record arguments" $ do
            findArgs args0
                `shouldBe`
                    Just "data Args = Args { fooId :: Int , barId :: Int }"
        it "finds positional arguments" $ do
            findArgs args1
                `shouldBe`
                    Just "data Args = Args Int String"
        it "works with deriving" $ do
            findArgs args2
                `shouldBe`
                    Just "data Args = Args Int String deriving (Eq, Show)"

    describe "processPositional" $ do
        it "formats positional arguments" $ do
            processPositional "data Args = Args Int String"
                `shouldBe`
                    PositionalArgs ["Int", "String"]
        it "works with type constructors" $ do
            processPositional "data Args = Args (Maybe String) Int"
                `shouldBe`
                    PositionalArgs ["(Maybe String)", "Int"]
        it "is fine with deriving" $ do
            processPositional "data Args = Args (Maybe String) Int deriving Show"
                `shouldBe`
                    PositionalArgs ["(Maybe String)", "Int"]

    describe "collectTopLevelParens" $ do
        it "works on zero layers" $ do
            collectTopLevelParens "hey foo bar"
                `shouldBe`
                    ["hey", "foo", "bar"]

        it "works on two layers" $ do
            collectTopLevelParens "hey (foo bar) baz"
                `shouldBe`
                    ["hey", "(foo bar)", "baz"]

        it "works on three layers" $ do
            collectTopLevelParens "hey (foo (bar baz)) yes"
                `shouldBe`
                    ["hey", "(foo (bar baz))", "yes"]

    describe "isValidModuleName" $ do
        it "must start with uppercase letter" $ do
            isValidModuleName "Yes" `shouldBe` True
        it "must not be empty" $ do
            isValidModuleName "" `shouldBe` False



args0 :: FileContent
args0 = FileContent $ unlines
    [ "module ASdf where"
    , ""
    , "data Args"
    , "  = Args"
    , "  { fooId :: Int"
    , "  , barId :: Int"
    , "  }"
    ]

args1 :: FileContent
args1 = FileContent $ unlines
    [ "module ASdf where"
    , ""
    , "data Args"
    , "  = Args Int String"
    ]

args2 :: FileContent
args2 = FileContent $ unlines
    [ "module FooBar where"
    , "data Args"
    , " = Args Int String"
    , " deriving (Eq, Show)"
    ]

decs0 :: String
decs0 = unlines
    [ "module Foo where"
    , ""
    , "import Asdf"
    , ""
    , "data Foo"
    , "  = Bar"
    , "  | Baz"
    ]

decs1 :: String
decs1 = unlines
    [ "data Foo"
    , " = Bar"
    ]

decs2 :: String
decs2 = unlines
    [ "module Wat where"
    , "data Foo = Foo"
    , "  { fooName :: String"
    , "  , fooAge  :: Int"
    , "  }"
    ]

decs3 :: String
decs3 = unlines
    [ "data Foo = Foo {"
    , " fooName :: String"
    , "}"
    ]

task0 :: Task
task0 = Task (TaskModule "Module.Foo") (stripArgs "data Args = Args { foo :: Int }") (TaskName "Name")

task1 :: Task
task1 = Task (TaskModule "Module1.Foo") NoArgs (TaskName "Other_Name")

task2 :: Task
task2 = Task
    (TaskModule "Module1.Bar")
    (PositionalArgs ["Int", "(Maybe String)"])
    (TaskName "Yes_Name")
