if [ $# -eq 0 ]; then
    echo "input version argument"
    exit 1
fi

# Check if the argument is a valid version string
if ! [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Invalid version string. Please provide a version in the format X.Y.Z"
    exit 1
fi

tag=$1

# Replace version string in podspec files
sed -i '' "s/s.version          = '.*'/s.version          = '$tag'/" AlgoLoggerCommon.podspec
sed -i '' "s/s.version          = '.*'/s.version          = '$tag'/" AlgoLogger.podspec
sed -i '' "s/s.dependency 'AlgoLoggerCommon', '~> .*'/s.dependency 'AlgoLoggerCommon', '~> $tag'/" AlgoLogger.podspec
sed -i '' "s/s.version          = '.*'/s.version          = '$tag'/" AlgoLoggerAWS.podspec
sed -i '' "s/s.dependency 'AlgoLogger', '~> .*'/s.dependency 'AlgoLogger', '~> $tag'/" AlgoLoggerAWS.podspec
