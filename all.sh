oldlist()
{
	echo "**** $1 ****"
	./configure --list-$1

}

list() {
    local command_argument="$1"
    # Execute the command and capture the output
    local input_string=$(./configure --list-"$command_argument")
#	echo "$input_string for $1"

    # Read the output string into an array, splitting by whitespace
    echo "$input_string" | tr -s '[:space:]' '\n' | while read -r word; do
            echo "$command_argument $word"
    done


}


list demuxers
list parsers
list encoders
list decoders
list filters

