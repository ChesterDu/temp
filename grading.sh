#!/bin/bash

usage() {
cat <<-EOF
Usage: $0 [OPTIONS]

Options include:
    -n STUDENT_NETID    NetID of the student.
    -g GROUP_NAME       Group name of the student.
    -m MP               The MP you want to check out
                        Valid inputs are mp1, mp2.1, mp2.2, mp3.1, etc.
    -d DUE_DATE         Due date of MP in format "YYYY-MM-DD".
                        Optional, this is required for SVN, not Git.
    -t DUE_TIME         Due time of MP in format "HH:MM:SS" (24 hour).
                        Optional, use default time 18:00:00 if not given.
    -s                  Optional, use SVN if provided, use Git if not provided.
    -h                  This helpful text.

Example:
    $0 -d 2016-03-28 -t 23:59:00 -m mp2.2 -n aaa1
    This will check out MP2.2 for NetID "aaa1".
    Due date is March 28, 2016, due time is 11:59pm.

    $0 -d 2016-04-28 -m mp3 -g aaOS
    This will check out MP3 for group "aaOS".
    Due date is April 28, 2016, due time is 06:00pm.
EOF
    exit 1
}

svn_make() {
    if [ "$#" -eq 1 ]; then
        repo="$1"
    elif [ "$#" -eq 2 ]; then
        repo="$1"
        cpoint="$2"
    else
        return -1
    fi

    rm -rf grading_svn_co

    if [ "$(date +'%m')" -le 6 ]; then
        semester="sp$(date +'%y')"
    else
        semester="fa$(date +'%y')"
    fi

    if [[ "$repo" == "mp1" ]] || [[ "$repo" == "mp2" ]]; then
        rm -rf $netid
        svn_check="$(svn info https://subversion.ews.illinois.edu/svn/$semester-ece391/$netid)"
        if [ -z "$svn_check" ]; then
            echo -e "Error: cannot find the student's repo\n"
            return -1
        fi
        echo -e "Starting SVN checkout\n"
        svn co https://subversion.ews.illinois.edu/svn/$semester-ece391/$netid grading_svn_co

        cd grading_svn_co
        if [ -z "$dtime" ]; then
            dtime="18:00:00"
        fi
        svn up -r {"$ddate $dtime"}
        cd ..

        if [[ "$repo" == "mp1" ]]; then
            mp12_dir="$(find ./grading_svn_co -name mp1.S -type f)"
        else
            mp12_dir="$(find ./grading_svn_co -name modex.c -type f)"
        fi

        mp12_dir="$(dirname $mp12_dir)"
        mv $mp12_dir $netid
        rm -rf grading_svn_co
        cd $netid
        if [[ "$repo" == "mp1" ]]; then
            if [[ "$semester" == "sp"* ]]; then
				/bin/cp -f /ece391/mp1/Makefile ./
                /bin/cp -f /ece391/mp1/frame0.txt ./
                /bin/cp -f /ece391/mp1/frame1.txt ./
			else
				/bin/cp -f /ece391/mp1/Makefile ./
            fi
        else
            /bin/cp -f /ece391/mp2/Makefile ./
            /bin/cp -f /ece391/mp2/module/Makefile ./module/
        fi
    else
        rm -rf $group
        svn_check="$(svn info https://subversion.ews.illinois.edu/svn/$semester-ece391/_projects/$group)"
        if [ -z "$svn_check" ]; then
            svn_check="$(svn info https://subversion.ews.illinois.edu/svn/$semester-ece391/$group)"
            if [ -z "$svn_check" ]; then
                echo -e "Error: cannot find the student's repo\n"
                return -1
            else
                echo -e "Starting SVN checkout\n"
                svn co https://subversion.ews.illinois.edu/svn/$semester-ece391/$group grading_svn_co
            fi
        else
            echo -e "Starting SVN checkout\n"
            svn co https://subversion.ews.illinois.edu/svn/$semester-ece391/_projects/$group grading_svn_co
        fi

        cd grading_svn_co
        if [ -z "$dtime" ]; then
            dtime="18:00:00"
        fi
        svn up -r {"$ddate $dtime"}
        cd ..

        trunk="$(find ./grading_svn_co -name trunk -type d)"
        if [ -z "$trunk" ]; then
            mp3_dir="$(find ./grading_svn_co -name student-distrib -type d)"
        else
            mp3_dir="$(find $trunk -name student-distrib -type d)"
        fi
        mp3_dir="$(dirname $mp3_dir)"

        mv $mp3_dir $group
        rm -rf grading_svn_co
        cd $group/student-distrib
    fi

    curr_dir="$(pwd)"
    echo -e "\nCurrent directory is: \e[41m${curr_dir}\e[49m"
    echo -e "\nPlease make sure this is the right directory before continuing!\n"
    read -p "Press any key to start compiling the MP..." -n1 -s
    echo -e "\n"

    if [[ "$repo" == "mp3" ]]; then
        dir_check="$(cut -d / -f 2 <<< $curr_dir)"
        if [[ "$dir_check" == "workdirmain" ]]; then
            prefix="$(cut -d / -f 1-4 <<< $curr_dir)"
        else
            prefix="$(cut -d / -f 1-2 <<< $curr_dir)"
        fi
        temp='Z:'${curr_dir#$prefix}'/mp3.img'
        for (( i=0; i<${#temp}; i++ )); do
            if [[ "${temp:$i:1}" == "/" ]]; then
                hex="$(echo "\\" | od -t x1 | cut -d ' ' -f 2 | head -1)"
            else
                hex="$(echo ${temp:$i:1} | od -t x1 | cut -d ' ' -f 2 | head -1)"
            fi
            lnk2=$lnk2"\\x$hex\\x00"
        done
        lnk=$lnk1$lnk2$lnk3

        if [ -z "$winshare" ]; then
            echo -n -e $lnk > /workdir/mp3_grading.lnk
        else
            echo -n -e $lnk > /windesktop/mp3_grading.lnk
        fi

        /bin/cp -f /ece391/mp3/student-distrib/mp3.img ./
        /bin/cp -f /ece391/mp3/student-distrib/filesys_img ./
        /bin/cp -f /ece391/mp3/student-distrib/debug.sh ./
        /bin/cp -f /ece391/mp3/student-distrib/Makefile ./
        chmod a+x debug.sh
        sudo make clean
        make -sB dep
        sudo make -sB
    else
        make clean
        make -sB
    fi

    echo -e "\nCompilation complete, please check for warnings and errors!\n"

    if [[ "$repo" == "mp1" ]]; then
        read -p "Press any key to start compiling the kernel..." -n1 -s
        echo -e "\n"
        mp_dir="$(pwd)"
        /bin/cp -f mp1.S /workdir/source/linux-2.6.22.5/drivers/char
        cd /home/user/build
        make
        make install
        cd $mp_dir
    fi

    if [ "$#" -eq 2 ] && [[ "$repo" == "mp2" ]] && [[ "$cpoint" == "2" ]]; then
        cd module
        read -p "Press any key to start compiling the TUX module..." -n1 -s
        echo -e "\n"
        make clean
        make -sB
        echo -e "\nCompilation complete, please check for warnings and errors!\n"
        read -p "Press any key to continue..." -n1 -s
        echo -e "\n"

        mod_check="$(/sbin/lsmod)"
        if [[ "$mod_check" == *"tuxctl"* ]]; then
            sudo /sbin/rmmod tuxctl
        fi
        sudo /sbin/insmod ./tuxctl.ko

        cd ..
        /bin/cp -f /ece391/staff_files/simpletest ./
        /bin/cp -f /ece391/staff_files/stafftest.c ./
        gcc -o stafftest stafftest.c
    fi

    return 0
}

git_download() {
    if [ "$#" -eq 1 ]; then
        repo="$1"
    elif [ "$#" -eq 2 ]; then
        repo="$1"
        cpoint="$2"
    else
        return -1
    fi

    rm -rf grading_git_clone

    if [ "$(date +'%m')" -le 6 ]; then
        semester="sp$(date +'%y')"
    else
        semester="fa$(date +'%y')"
    fi

    git config --global core.autocrlf input
    git config --global core.eol lf

    if [[ "$repo" == "mp1" ]] || [[ "$repo" == "mp2" ]]; then
        if [ -f ~/.ssh/id_rsa ]; then
            git_link="git@gitlab.engr.illinois.edu:ece391_${semester}/${repo}_${netid}.git"
        else
            git_link="https://gitlab.engr.illinois.edu/ece391_${semester}/${repo}_${netid}.git"
        fi

        rm -rf $netid
        git ls-remote $git_link &> /dev/null
        git_check=$?

        if [ "$git_check" -ne 0 ]; then
            echo -e "\nError: cannot find the student's repo\n"
            return -1
        fi
        echo -e "\nStarting Git clone\n"
        git clone "$git_link" grading_git_clone

        cd grading_git_clone
        if [ -z "$dtime" ]; then
            dtime="18:00:00"
        fi
        t1="$(date --date="$ddate $dtime" +%s)"
        t2="$(date -u +%s)"
        echo -e "\nChecking out commit before: $ddate $dtime\n"
        git checkout "$(git rev-list -n 1 --before="$ddate $dtime" master)"
        cd ..

        if [[ "$repo" == "mp1" ]]; then
            mp12_dir="$(find ./grading_git_clone -name mp1.S -type f)"
        else
            mp12_dir="$(find ./grading_git_clone -name modex.c -type f)"
        fi

        mp12_dir="$(dirname $mp12_dir)"
        mv $mp12_dir $netid
        rm -rf grading_git_clone
        cd $netid
        if [[ "$repo" == "mp1" ]]; then
            if [[ "$semester" == "sp"* ]]; then
				/bin/cp -f /v/ece391/mp1/Makefile ./
                /bin/cp -f /v/ece391/mp1/frame0.txt ./
                /bin/cp -f /v/ece391/mp1/frame1.txt ./
			else
				/bin/cp -f /v/ece391/mp1/Makefile ./
            fi
        else
            /bin/cp -f /v/ece391/mp2/Makefile ./
            /bin/cp -f /v/ece391/mp2/module/Makefile ./module/
        fi

        echo -e "\nGit clone finished, please run the script again in devel with NetID: \e[41m${netid}\e[49m"
        echo -e "\nNote: don't provide the \"-s\" flag or you will delete the existing files"
    else
        if [ -f ~/.ssh/id_rsa ]; then
            git_link="git@gitlab.engr.illinois.edu:ece391_${semester}/${group}.git"
        else
            git_link="https://gitlab.engr.illinois.edu/ece391_${semester}/${group}.git"
        fi

        rm -rf $group
        git ls-remote $git_link &> /dev/null
        git_check=$?

        if [ "$git_check" -ne 0 ]; then
            echo -e "\nError: cannot find the student's repo\n"
            return -1
        fi
        echo -e "\nStarting Git clone\n"
        git clone "$git_link" grading_git_clone

        cd grading_git_clone
        if [ -z "$dtime" ]; then
            dtime="18:00:00"
        fi
        t1="$(date --date="$ddate $dtime" +%s)"
        t2="$(date -u +%s)"
        echo -e "\nChecking out commit before: $ddate $dtime\n"
        git checkout "$(git rev-list -n 1 --before="$ddate $dtime" master)"
        cd ..

        mp3_dir="$(find ./grading_git_clone -name student-distrib -type d)"
        mp3_dir="$(dirname $mp3_dir)"

        mv $mp3_dir $group
        rm -rf grading_git_clone
        cd $group/student-distrib
        /bin/cp -f /v/ece391/mp3/student-distrib/mp3.img ./
        /bin/cp -f /v/ece391/mp3/student-distrib/filesys_img ./
        /bin/cp -f /v/ece391/mp3/student-distrib/debug.sh ./
        /bin/cp -f /v/ece391/mp3/student-distrib/Makefile ./
        chmod a+x debug.sh

        curr_dir="$(pwd)"
        prefix="$(cut -d / -f 1-2 <<< $curr_dir)"
        temp='Z:'${curr_dir#$prefix}'/mp3.img'
        for (( i=0; i<${#temp}; i++ )); do
            if [[ "${temp:$i:1}" == "/" ]]; then
                hex="$(echo "\\" | od -t x1 | cut -d ' ' -f 2 | head -1)"
            else
                hex="$(echo ${temp:$i:1} | od -t x1 | cut -d ' ' -f 2 | head -1)"
            fi
            lnk2=$lnk2"\\x$hex\\x00"
        done
        lnk=$lnk1$lnk2$lnk3
        echo -n -e $lnk > /u/Desktop/mp3_grading.lnk

        cd $grading_dir
        compile_fname=${group,,}
        echo -e "#!/bin/bash\n\ncd ${group}/student-distrib\nsudo make clean" > "${compile_fname}.sh"
        echo -e "/bin/cp -f /ece391/mp3/student-distrib/mp3.img ./" >> "${compile_fname}.sh"
        echo -e "/bin/cp -f /ece391/mp3/student-distrib/filesys_img ./" >> "${compile_fname}.sh"
        echo -e "/bin/cp -f /ece391/mp3/student-distrib/debug.sh ./" >> "${compile_fname}.sh"
        echo -e "/bin/cp -f /ece391/mp3/student-distrib/Makefile ./" >> "${compile_fname}.sh"
        echo -e "make -sB dep\nsudo make -sB" >> "${compile_fname}.sh"
        chmod a+x "${compile_fname}.sh"

        echo -e "\nGit clone finished, please run the script again in devel with group name: \e[41m${group}\e[49m"
        echo -e "\nNote: don't provide the \"-s\" flag or you will delete the existing files"
    fi

    return 0
}

git_make() {
    if [ "$#" -eq 1 ]; then
        repo="$1"
    elif [ "$#" -eq 2 ]; then
        repo="$1"
        cpoint="$2"
    else
        return -1
    fi

    if [ "$(date +'%m')" -le 6 ]; then
        semester="sp$(date +'%y')"
    else
        semester="fa$(date +'%y')"
    fi

    if [[ "$repo" == "mp1" ]] || [[ "$repo" == "mp2" ]]; then
        cd $netid
    else
        cd $group/student-distrib
    fi

    curr_dir="$(pwd)"
    echo -e "\nCurrent directory is: \e[41m${curr_dir}\e[49m"
    echo -e "\nPlease make sure this is the right directory before continuing!\n"
    read -p "Press any key to start compiling the MP..." -n1 -s
    echo -e "\n"

    if [[ "$repo" == "mp3" ]]; then
        /bin/cp -f /ece391/mp3/student-distrib/mp3.img ./
        /bin/cp -f /ece391/mp3/student-distrib/filesys_img ./
        /bin/cp -f /ece391/mp3/student-distrib/debug.sh ./
        /bin/cp -f /ece391/mp3/student-distrib/Makefile ./
        chmod a+x debug.sh
        sudo make clean
        make -sB dep
        sudo make -sB
    else
        make clean
        make -sB
    fi

    echo -e "\nCompilation complete, please check for warnings and errors!\n"

    if [[ "$repo" == "mp1" ]]; then
        read -p "Press any key to start compiling the kernel..." -n1 -s
        echo -e "\n"
        mp_dir="$(pwd)"
        /bin/cp -f mp1.S /workdir/source/linux-2.6.22.5/drivers/char
        cd /home/user/build
        make
        make install
        cd $mp_dir
    fi

    if [ "$#" -eq 2 ] && [[ "$repo" == "mp2" ]] && [[ "$cpoint" == "2" ]]; then
        cd module
        read -p "Press any key to start compiling the TUX module..." -n1 -s
        echo -e "\n"
        make clean
        make -sB
        echo -e "\nCompilation complete, please check for warnings and errors!\n"
        read -p "Press any key to continue..." -n1 -s
        echo -e "\n"

        mod_check="$(/sbin/lsmod)"
        if [[ "$mod_check" == *"tuxctl"* ]]; then
            sudo /sbin/rmmod tuxctl
        fi
        sudo /sbin/insmod ./tuxctl.ko

        cd ..
        /bin/cp -f /ece391/staff_files/simpletest ./
        /bin/cp -f /ece391/staff_files/stafftest.c ./
        gcc -o stafftest stafftest.c
    fi

    return 0
}

netid=
group=
mp=
checkp=
ddate=
dtime=
use_svn=
system="$(uname)"
grading_dir="$(pwd)"

if [ "$#" -eq 0 ]; then
    usage
else
    while [[ "$1" = -* ]]; do
        opt="$1"
        shift

        if [ "$opt" == "-m" ]; then
            mp="$(cut -d. -f 1 <<< $1 | tr '[:upper:]' '[:lower:]')"
            checkp="$(cut -d. -f 2 <<< $1)"
            if [ "$mp" != "mp1" ] && [ "$mp" != "mp2" ] && [ "$mp" != "mp3" ]; then
                echo -e "Error: \"$1\" is not a valid input for MP\n"
                usage
            fi
            shift
        elif [ "$opt" == "-n" ]; then
            if [[ ! "$1" =~ ^[a-z]+[0-9]*$ ]]; then
                echo -e "Error: \"$1\" is not a valid input for NetID\n"
                usage
            fi
            netid="$1"
            shift
        elif [ "$opt" == "-g" ]; then
            temp="$(echo $1 | tr ' ' '_')"
            if [[ ! "$temp" =~ ^[a-zA-Z0-9\_]+$ ]]; then
                echo -e "Error: \"$1\" is not a valid input for group name\n"
                usage
            fi
            group="$temp"
            shift
        elif [ "$opt" == "-d" ]; then
            ddate="$(date '+%Y-%m-%d' -d $1)"
            if [[ "$ddate" == *"invalid date"* ]] || [[ ! "$1" =~ ^[0-9]{4}\-[0-9]{2}\-[0-9]{2}$ ]]; then
                echo -e "Error: \"$1\" is not a valid input for due date\n"
                usage
            fi
            shift
        elif [ "$opt" == "-t" ]; then
            dtime="$(date '+%H:%M:%S' -d $1)"
            if [[ "$dtime" == *"invalid date"* ]] || ([[ ! "$1" =~ ^[0-9]{2}\:[0-9]{2}\:[0-9]{2}$ ]] && [[ ! "$1" =~ ^[0-9]{2}\:[0-9]{2}$ ]]); then
                echo -e "Error: \"$1\" is not a valid input for due time\n"
                usage
            fi
            shift
        elif [ "$opt" == "-s" ]; then
            if [ "$system" == "Linux" ]; then
                use_svn="true"
            else
                echo -e "Warning: ignoring \"-s\" since your are using git-bash"
            fi
        else
            usage
        fi
    done
fi

if [ -z "$mp" ]; then
    echo -e "Error: must select an MP to checkout\n"
    usage
elif [ -z "$ddate" ] && [[ "$use_svn" == "true" || "$system" != "Linux" ]]; then
    echo -e "Error: must input the due date of MP\n"
    usage
elif [ "$mp" == "mp3" ]; then
    if [ -z "$group" ]; then
        echo -e "Error: must input a group name for MP3\n"
        usage
    elif [ "$checkp" -lt "1" ] || [ "$checkp" -gt "5" ]; then
        echo -e "Error: invalid checkpoint for MP3 (e.g. for checkpoint 1 please use mp3.1)\n"
        usage
    else
        lnk1="\x4c\x00\x00\x00\x01\x14\x02\x00\x00\x00\x00\x00\xc0\x00\x00\x00\x00\x00\x00\x46\xb3\x00\x08\x00\x20\x00\x00\x00\xc7\xde\x83\x38\x4c\x96\xce\x01\xc7\xde\x83\x38\x4c\x96\xce\x01\x00\x84\x97\x6a\xd6\x55\xce\x01\x0e\x1c\x4a\x00\x00\x00\x00\x00\x07\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x15\x01\x14\x00\x1f\x50\xe0\x4f\xd0\x20\xea\x3a\x69\x10\xa2\xd8\x08\x00\x2b\x30\x30\x9d\x19\x00\x2f\x43\x3a\x5c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x72\x00\x31\x00\x00\x00\x00\x00\x1a\x43\xd1\x7e\x10\x00\x51\x45\x4d\x55\x2d\x31\x7e\x31\x2e\x30\x2d\x57\x00\x00\x56\x00\x08\x00\x04\x00\xef\xbe\x0b\x43\x72\x24\x1a\x43\xd1\x7e\x2a\x00\x00\x00\x4a\x67\x01\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x71\x00\x65\x00\x6d\x00\x75\x00\x2d\x00\x31\x00\x2e\x00\x35\x00\x2e\x00\x30\x00\x2d\x00\x77\x00\x69\x00\x6e\x00\x33\x00\x32\x00\x2d\x00\x73\x00\x64\x00\x6c\x00\x00\x00\x1c\x00\x74\x00\x32\x00\x0e\x1c\x4a\x00\xb5\x42\x62\x1e\x20\x00\x51\x45\x35\x32\x43\x44\x7e\x31\x2e\x45\x58\x45\x00\x00\x58\x00\x08\x00\x04\x00\xef\xbe\x0b\x43\x72\x24\x0b\x43\x72\x24\x2a\x00\x00\x00\x45\x1b\x0f\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x71\x00\x65\x00\x6d\x00\x75\x00\x2d\x00\x73\x00\x79\x00\x73\x00\x74\x00\x65\x00\x6d\x00\x2d\x00\x69\x00\x33\x00\x38\x00\x36\x00\x77\x00\x2e\x00\x65\x00\x78\x00\x65\x00\x00\x00\x1c\x00\x00\x00\x5e\x00\x00\x00\x1c\x00\x00\x00\x01\x00\x00\x00\x1c\x00\x00\x00\x2f\x00\x00\x00\x00\x00\x00\x00\x5d\x00\x00\x00\x13\x00\x00\x00\x03\x00\x00\x00\x3a\xd2\xcd\x1a\x10\x00\x00\x00\x4f\x53\x00\x43\x3a\x5c\x71\x65\x6d\x75\x2d\x31\x2e\x35\x2e\x30\x2d\x77\x69\x6e\x33\x32\x2d\x73\x64\x6c\x5c\x71\x65\x6d\x75\x2d\x73\x79\x73\x74\x65\x6d\x2d\x69\x33\x38\x36\x77\x2e\x65\x78\x65\x00\x00\x18\x00\x43\x00\x3a\x00\x5c\x00\x71\x00\x65\x00\x6d\x00\x75\x00\x2d\x00\x31\x00\x2e\x00\x35\x00\x2e\x00\x30\x00\x2d\x00\x77\x00\x69\x00\x6e\x00\x33\x00\x32\x00\x2d\x00\x73\x00\x64\x00\x6c\x00\x5c\x00\xff\x00\x2d\x00\x68\x00\x64\x00\x61\x00\x20\x00\x22\x00"
        lnk2=
        lnk3="\x22\x00\x20\x00\x2d\x00\x6d\x00\x20\x00\x35\x00\x31\x00\x32\x00\x20\x00\x2d\x00\x67\x00\x64\x00\x62\x00\x20\x00\x74\x00\x63\x00\x70\x00\x3a\x00\x31\x00\x32\x00\x37\x00\x2e\x00\x30\x00\x2e\x00\x30\x00\x2e\x00\x31\x00\x3a\x00\x31\x00\x32\x00\x33\x00\x34\x00"
        if [ "$use_svn" == "true" ]; then
            first_char=${ADUSER:0:1}
            if [[ $first_char == [a-c] ]]; then
                winshare="fs1-homes"
            elif [[ $first_char == [d-h] ]]; then
                winshare="fs2-homes"
            elif [[ $first_char == [i-l] ]]; then
                winshare="fs3-homes"
            elif [[ $first_char == [m-p] ]]; then
                winshare="fs4-homes"
            elif [[ $first_char == [q-s] ]]; then
                winshare="fs5-homes"
            elif [[ $first_char == [t-z] ]]; then
                winshare="fs6-homes"
            else
                winshare=
                echo -e "Warning: cannot determine windows home directory"
                echo -e "         mp3 grading link will be placed in workdir\n"
            fi

            if [ -n "$winshare" ]; then
                if [ ! -d "/winhome" ]; then
                    sudo mkdir /winhome
                    echo -e "\nMounting windows home directory, enter your AD password below"
                    sudo mount -t cifs -o user=$ADUSER,domain=uofi,uid=501,gid=501 //engr-ews-homes.engr.illinois.edu/$winshare /winhome
                    sudo rm -rf /windesktop
                    sudo ln -s /winhome/$ADUSER/windows/Desktop /windesktop
                    echo -e "\nWindows home directory successfully mounted\n"
                else
                    mount_check="$(sudo mount)"
                    if [[ ! $mount_check == *"winhome"* ]]; then
                        echo -e "\nMounting windows home directory, enter your AD password below"
                        sudo mount -t cifs -o user=$ADUSER,domain=uofi,uid=501,gid=501 //engr-ews-homes.engr.illinois.edu/$winshare /winhome
                        sudo rm -rf /windesktop
                        sudo ln -s /winhome/$ADUSER/windows/Desktop /windesktop
                        echo -e "\nWindows home directory successfully mounted\n"
                    else
                        echo -e "\nWindows home directory already mounted\n"
                    fi
                fi
            fi

            svn_make "mp3" "$checkp"
        elif [ ! "$system" == "Linux" ]; then
            git_download "mp3" "$checkp"
        else
            git_make "mp3" "$checkp"
        fi
    fi
else
    if [ -z "$netid" ]; then
        echo -e "Error: must input a netid for MP1 or MP2\n"
        usage
    elif [ "$mp" == "mp1" ]; then
        if [ "$use_svn" == "true" ]; then
            svn_make "mp1"
        elif [ ! "$system" == "Linux" ]; then
            git_download "mp1"
        else
            git_make "mp1"
        fi
    elif [ "$mp" == "mp2" ] && [ "$checkp" == "1" ]; then
        if [ "$use_svn" == "true" ]; then
            svn_make "mp2" "1"
        elif [ ! "$system" == "Linux" ]; then
            git_download "mp2" "1"
        else
            git_make "mp2" "1"
        fi

    elif [ "$mp" == "mp2" ] && [ "$checkp" == "2" ]; then
        if [ "$use_svn" == "true" ]; then
            svn_make "mp2" "2"
        elif [ ! "$system" == "Linux" ]; then
            git_download "mp2" "2"
        else
            git_make "mp2" "2"
        fi
    else
        echo -e "Error: invalid checkpoint for MP2 (e.g. for checkpoint 1 please use mp2.1)\n"
        usage
    fi
fi

exit 0
