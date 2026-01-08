mkdir -p bin
rm bin/ff*


docker build --progress=plain -t ffmpeg .

docker rmi fflinux

docker run --name fflinux ffmpeg


# docker cp fflinux:/build/artifacts/ffmpeg-5.1.2-audio-x86_64-linux-gnu/bin/ffmpeg ./bin/
# docker cp fflinux:/build/artifacts/ffmpeg-5.1.2-audio-x86_64-linux-gnu/bin/ffprobe ./bin/
# Dockerfile moves artifacts to /build/bin

docker cp fflinux:/build/bin/ffmpeg ./bin/
docker cp fflinux:/build/bin/ffprobe ./bin/


