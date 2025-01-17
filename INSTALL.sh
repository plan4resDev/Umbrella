#!/bin/bash

# version sandrine
# ------------------------------------------------------------------------------
# SYNOPSIS
#     This script installs SMS++ and all its dependencies on Unix-based systems.
#
# DESCRIPTION
#     This script performs the installation of SMS++ and all its dependencies
#     on Unix-based systems. If not already present, it clones the smspp-project
#     repositories, then builds and installs them.
#
#     You can use the `--install-root=<your-custom-path>` option to specify your custom installation root.
#     You can use the `--without-cplex` option to skip the installation of CPLEX.
#     You can use the `--without-gurobi` option to skip the installation of Gurobi.
#
# AUTHOR
#     Donato Meoli
#
# EXAMPLES
#     If you are inside the cloned repository:
#
#         sudo ./INSTALL.sh --install-root=<your-custom-path>
#
#     or:
#
#         sudo ./INSTALL.sh --install-root=<your-custom-path> --without-cplex --without-gurobi
#
#     if you do not have a CPLEX and/or Gurobi license, or if you just want to install SMS++ without them.
#
#     If you have not yet cloned the SMS++ repository, you can run the script directly:
#
#     Using `curl`:
#
#         If you want to install SMS++ with all dependencies:
#
#             curl -s https://gitlab.com/smspp/smspp-project/-/raw/develop/INSTALL.sh | sudo bash -s -- --install-root=<your-custom-path>
#
#         or:
#
#             curl -s https://gitlab.com/smspp/smspp-project/-/raw/develop/INSTALL.sh | sudo bash -s -- --install-root=<your-custom-path> --without-cplex --without-gurobi
#
#        if you do not have a CPLEX and/or Gurobi license, or if you just want to install SMS++ without them.
#
#     Using `wget`:
#
#         If you want to install SMS++ with all dependencies:
#
#             wget -qO- https://gitlab.com/smspp/smspp-project/-/raw/develop/INSTALL.sh | sudo bash -s -- --install-root=<your-custom-path>
#
#         or:
#
#             wget -qO- https://gitlab.com/smspp/smspp-project/-/raw/develop/INSTALL.sh | sudo bash -s -- --install-root=<your-custom-path> --without-cplex --without-gurobi
#
#         if you do not have a CPLEX and/or Gurobi license, or if you just want to install SMS++ without them.
# ------------------------------------------------------------------------------

delete_files() {
    for pattern in "$@"; do
		for file in $pattern; do
			if [ -e "$file" ]; then
				rm "$file"
				echo "Deleted: $file"
			else
				echo "File not found: $file"
			fi
		done
	done
}

delete_dirs() {
    for pattern in "$@"; do
		for dir in $pattern; do
			if [ -d "$dir" ]; then
				rm -rf "$dir"
				echo "Deleted directory: $dir"
			else
				echo "Directory not found: $dir"
			fi
		done
	done
}


# Function to install dependencies on Ubuntu
install_on_linux() {
  set -e  # Exit immediately if a command exits with a non-zero status

  echo "Starting the installation process on Linux..."

  if [[ "$HAS_SUDO" -eq 1 && "$update_linux" -eq 1 ]]; then
    # Update packages and install basic requirements
    echo "Updating system and installing basic requirements..."
    apt-get update -q
    apt-get install -y -q build-essential clang cmake cmake-curses-gui git curl xterm

    # Install Boost libraries
    echo "Installing Boost libraries..."
    apt-get install -y -q libboost-dev libboost-system-dev libboost-timer-dev libboost-mpi-dev libboost-random-dev

    # Install OpenMP
    echo "Installing OpenMP..."
    apt-get install -y -q libomp-dev

    # Install Eigen
    echo "Installing Eigen..."
    apt-get install -y -q libeigen3-dev

    # Install NetCDF-C++
    echo "Installing NetCDF-C++..."
    apt-get install -y -q libnetcdf-c++4-dev
  fi

  # Install CPLEX
  if [ "$install_cplex" -eq 1 ]; then
    echo "Installing CPLEX..."
	#CPLEX_ROOT="${INSTALL_ROOT}/ibm/ILOG/CPLEX_Studio"
    CPLEX_ROOT="${INSTALL_ROOT}/cplex"
    if [ ! -d "$CPLEX_ROOT" ]; then  # this test doesn't work if the install has started but failed
      cd "$INSTALL_ROOT"
	  if [ ! "$cplex_installer" = "" ]; then
		cplex_installer=$cplex_installer
	  else
		cplex_installer="cplex_studio2211.linux_x86_64.bin"
	  fi
      # the CPLEX_URL is always given by the same prefix, i.e.:
      # "https://drive.usercontent.google.com/download?id=" +
      # the id code suffix in the Drive sharing link, i.e.:
      # https://drive.google.com/file/d/ 12JpuzOAjnuQK6tq2LLolIgmlmKTmOP4x /view?usp=sharing
      if [ "$cplex_installer" = "" ]; then
		CPLEX_URL="https://drive.usercontent.google.com/download?id=12JpuzOAjnuQK6tq2LLolIgmlmKTmOP4x"
		uuid=$(curl -sL "$CPLEX_URL" | grep -oE 'name="uuid" value="[^"]+"' | cut -d '"' -f 4)
		if [ -n "$uuid" ]; then
			curl -o "$cplex_installer" "$CPLEX_URL&export=download&authuser=0&confirm=t&uuid=$uuid"
			chmod u+x "$cplex_installer"
			cat <<EOL > installer.properties
INSTALLER_UI=silent
LICENSE_ACCEPTED=TRUE
USER_INSTALL_DIR=$CPLEX_ROOT
EOL
			./"$cplex_installer" -f ./installer.properties &
			wait $! # wait for CPLEX installer to finish
			INSTALLER_EXIT_CODE=$?
			if [ $INSTALLER_EXIT_CODE -eq 0 ]; then
			  rm "$cplex_installer" installer.properties
			  #mv ./ibm/ILOG/CPLEX_Studio2211 "$CPLEX_ROOT"
			  export CPLEX_HOME="${CPLEX_ROOT}/cplex"
			  export PATH="${PATH}:${CPLEX_HOME}/bin/x86-64_linux"
			  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${CPLEX_HOME}/lib/x86-64_linux"
			  if [[ "$HAS_SUDO" -eq 1 && "$update_linux" -eq 1 ]]; then
				sh -c "echo '${CPLEX_HOME}/lib/x86-64_linux' > /etc/ld.so.conf.d/cplex.conf"
				ldconfig
			  else
				rm -R javasharedresources
			  fi
			else
			  echo "CPLEX installation failed with exit code $INSTALLER_EXIT_CODE."
			  exit 1
			fi
		else
			echo "Error: unable to find the UUID value in the response. The CPLEX download link could not be constructed."
			exit 1
		fi
	  else
	   # install using the user's installer
		cat <<EOL > installer.properties
INSTALLER_UI=silent
LICENSE_ACCEPTED=TRUE
USER_INSTALL_DIR=$CPLEX_ROOT
CHECK_DISK_SPACE=OFF
EOL
		if [ -f "$cplex_installer" ]; then
			chmod +x $cplex_installer
			#./"$cplex_installer" -f ./installer.properties &
			#wait $! # wait for CPLEX installer to finish
			#INSTALLER_EXIT_CODE=$?
			INSTALLER_EXIT_CODE=0
			if [ $INSTALLER_EXIT_CODE -eq 0 ]; then
				rm installer.properties
				rm "$cplex_installer" 
				echo "CPLEX installation succeeded"
			else
				echo "CPLEX installation failed with exit code $INSTALLER_EXIT_CODE."
				exit 1
			fi
		else
			echo "Cplex installer does not exist"
			exit 1
		fi
	  fi
    else
      echo "CPLEX already installed."
    fi
  fi

  # Install Gurobi
  if [ "$install_gurobi" -eq 1 ]; then
    echo "Installing Gurobi..."
    GUROBI_ROOT="${INSTALL_ROOT}/gurobi"
    if [ ! -d "$GUROBI_ROOT" ]; then  # same comment than for cplex
      cd "$INSTALL_ROOT"
	  if [ ! "$gurobi_installer" = "" ]; then
		GUROBI_INSTALLER=$gurobi_installer
	  else
		GUROBI_INSTALLER="gurobi10.0.3_linux64.tar.gz"
	  fi
	  if [ "$gurobi_installer" = "" ]; then
		  curl -O "https://packages.gurobi.com/10.0/$GUROBI_INSTALLER"
		  tar -xvf "$GUROBI_INSTALLER"
		  rm "$GUROBI_INSTALLER"
		  mv ./gurobi1003 "$GUROBI_ROOT"
		  export GUROBI_HOME="${GUROBI_ROOT}/linux64"
		  export PATH="${PATH}:${GUROBI_HOME}/bin"
		  export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${GUROBI_HOME}/lib"
		  if [ "$HAS_SUDO" -eq 1 ]; then
			sh -c "echo '${GUROBI_HOME}/lib' > /etc/ld.so.conf.d/gurobi.conf"
			ldconfig
		  fi
      else
		if [ -f "$GUROBI_INSTALLER" ]; then
			#if [ ! -d "$GUROBI_ROOT" ]; then mkdir $GUROBI_ROOT; fi
			if [ -f "$gurobi_licence" ]; then
				cd $INSTALL_ROOT
				tar xvf $GUROBI_INSTALLER
				GRBDIR=$(tar tzf "$GUROBI_INSTALLER" | head -1 | cut -f1 -d"/")
				echo "gurdir: $GRBDIR"
				mv ./$GRBDIR "$GUROBI_ROOT"
				rm -rf $INSTALL_ROOT/$GUROBI_INSTALLER
			else
				echo "Gurobi licence does not exist"
				exit 1
			fi
		else
			echo "Gurobi installer does not exist"
			exit 1
		fi
	  fi
    else
      echo "Gurobi already installed."
    fi
  fi

  # Install SCIP
  echo "Installing SCIP...  "
  SCIP_ROOT="${INSTALL_ROOT}/scip"
  SCIP_BUILD_ROOT="${BUILD_ROOT}/scip"
  if [ "$install_scip" -eq 1 ]; then
    if [[ "$HAS_SUDO" -eq 1 && "$update_linux" -eq 1 ]]; then
      apt-get install -y -q gfortran libtbb-dev
    fi
    cd "$BUILD_ROOT"
    SCIP_INSTALLER="scip-9.2.0"
    curl -O "https://www.scipopt.org/download/release/$SCIP_INSTALLER.tgz"
    tar xvzf "$SCIP_INSTALLER.tgz"
    rm "$SCIP_INSTALLER.tgz"
	if [ -d $SCIP_BUILD_ROOT ]; then rm -rf $SCIP_BUILD_ROOT ; fi
	if [ ! -d $SCIP_ROOT ]; then mkdir $SCIP_ROOT ; fi
    mv ./"$SCIP_INSTALLER" "$SCIP_BUILD_ROOT"
    cd "$SCIP_BUILD_ROOT"
    cmake -S . -B build -DCMAKE_INSTALL_PREFIX="$SCIP_ROOT" -DAUTOBUILD=ON
    cmake --build build 
    cmake --install build --prefix "$SCIP_ROOT"
	#delete_dirs applications build check cmake doc examples make pclint scripts src tests
	#delete_files CHANGELOG CMakeLists.txt INSTALL_APPLICATIONS_EXAMPLES.md INSTALL.md Makefile README.md scip-config.cmake.in
    #rm -rf $SCIP_BUILD_ROOT
    if [[ "$HAS_SUDO" -eq 1 && "$update_linux" -eq 1 ]]; then
      sh -c "echo '${SCIP_ROOT}/lib' > /etc/ld.so.conf.d/scip.conf"
      ldconfig
    fi
  else
    echo "SCIP already installed."
  fi

  # Install HiGHS
  echo "Installing HiGHS......  install_highs=$install_highs"
  HiGHS_ROOT="${INSTALL_ROOT}/HiGHS"
  HiGHS_BUILD_ROOT="${BUILD_ROOT}/HiGHS"
  if [ "$install_highs" -eq 1 ]; then
    cd "$BUILD_ROOT"
	if [ ! -d ${BUILD_ROOT}/HiGHS ]; then
		git clone https://github.com/ERGO-Code/HiGHS.git
	else
		git pull
	fi
    cd HiGHS
    cmake -S . -B build -DFAST_BUILD=ON -DCMAKE_INSTALL_PREFIX="$HiGHS_ROOT"
    cmake --build build
    cmake --install build --prefix "$HiGHS_ROOT"
	#rm -rf $HiGHS_BUILD_ROOT
    if [[ "$HAS_SUDO" -eq 1 && "$update_linux" -eq 1 ]]; then
      sh -c "echo '${HiGHS_ROOT}/lib' > /etc/ld.so.conf.d/highs.conf"
      ldconfig
    fi	
	#delete_dirs app build check cmake examples extern nuget src subprojects tests 
	#delete_files BUILD.bazel build_webdemo.sh CmakeLists.txt FEATURES.md highs-config.cmake.in highs.pc.in meson.build meson_options.txt MODULE.bazel pyproject.toml WORKSPACE
  fi
 
  # Install COIN-OR CoinUtils and Osi/Clp
  echo "Installing COIN-OR CoinUtils and Osi/Clp... sudo=$HAS_SUDO"
  if [[ "$HAS_SUDO" -eq 1 && "$update_linux" -eq 1 ]]; then
    apt-get install -y -q coinor-libcoinutils-dev libbz2-dev liblapack-dev libopenblas-dev
  fi
  CoinOr_ROOT="${INSTALL_ROOT}/coin-or"
  CoinOr_BUILD_ROOT="${BUILD_ROOT}/coin-or"
  if [ "$install_coin" -eq 1 ]; then
    cd "$BUILD_ROOT"
    curl -O https://raw.githubusercontent.com/coin-or/coinbrew/master/coinbrew
    chmod u+x coinbrew
    # Build CoinUtils
    ./coinbrew build CoinUtils --latest-release --skip-dependencies --prefix="$CoinOr_ROOT" --tests=none
    # Build Osi with or without CPLEX
    osi_build_flags=(
      "--latest-release"
      "--skip-dependencies"
      "--prefix=$CoinOr_ROOT"
      "--tests=none"
    )
    if [ "$install_cplex" -eq 0 ]; then
      osi_build_flags+=("--without-cplex")
    else
      osi_build_flags+=(
        "--with-cplex"
        "--with-cplex-lib=-L${CPLEX_ROOT}/cplex/lib/x86-64_linux/static_pic -lcplex -lpthread -lm"
        "--with-cplex-incdir=${CPLEX_ROOT}/cplex/include/ilcplex"
      )
    fi
    # Build Osi with or without Gurobi
    if [ "$install_gurobi" -eq 0 ]; then
      osi_build_flags+=("--without-gurobi")
    else
      osi_build_flags+=(
        "--with-gurobi"
        "--with-gurobi-lib=-L${GUROBI_ROOT}/linux64/lib -lgurobi100"
        "--with-gurobi-incdir=${GUROBI_ROOT}/linux64/include"
      )
    fi
    ./coinbrew build Osi "${osi_build_flags[@]}"
    # Build Clp
    ./coinbrew build Clp --latest-release --skip-dependencies --prefix="$CoinOr_ROOT" --tests=none
    rm -Rf coinbrew build CoinUtils Osi Clp
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${CoinOr_ROOT}/lib"
    if [[ "$HAS_SUDO" -eq 1 && "$update_linux" -eq 1 ]]; then
      sh -c "echo '${CoinOr_ROOT}/lib' > /etc/ld.so.conf.d/coin-or.conf"
      ldconfig
    fi
	rm -rf ${CoinOr_BUILD_ROOT}
  else
    echo "COIN-OR already installed."
  fi

  # Install StOpt
  echo "Installing StOpt..."
  StOpt_ROOT="${INSTALL_ROOT}/StOpt"
  if [[ "$HAS_SUDO" -eq 1 && "$update_linux" -eq 1 ]]; then
    apt-get install -y -q zlib1g-dev
  fi
  if [ "$install_stopt" -eq 1 ]; then
    if [ -d $BUILD_ROOT/StOpt ]; then rm -rf $BUILD_ROOT/StOpt ; fi
    git clone https://gitlab.com/stochastic-control/StOpt.git $BUILD_ROOT
    cd $BUILD_ROOT/StOpt
    delete_dirs doc 
    cmake -S . -B build \
          -DBUILD_PYTHON=OFF \
          -DBUILD_TEST=OFF \
          -DCMAKE_INSTALL_PREFIX="$StOpt_ROOT" \
		  -DBOOST_ROOT=${BOOST_PATH} \
		  -DEIGEN3_INCLUDE_DIR=${EIGEN_PATH}/include/eigen3
		    
    cmake --build build
    cmake --install build --prefix "$StOpt_ROOT"
    #mv "${INSTALL_ROOT}/doc" StOpt_ROOT # TODO remove when the doc bug in StOpt will be fixed
    delete_dirs CMakeModules build "geners*" R test utils
	delete_files CmakeLists.txt "COPYING*" README.md "vcpkg*"
	cd "$INSTALL_ROOT"
  else
    if [ "$HAS_SUDO" -eq 1 ]; then
      cd "$StOpt_ROOT"
      LOCAL=$(git rev-parse @)
      REMOTE=$(git rev-parse @{u})
      # if the repository is not up to date
      if [ "$LOCAL" != "$REMOTE" ]; then
        git pull
        mv ./doc "${INSTALL_ROOT}" # TODO remove when the doc bug in StOpt will be fixed
        cmake -S . -B build \
              -DBUILD_PYTHON=OFF \
              -DBUILD_TEST=OFF \
              -DCMAKE_INSTALL_PREFIX="$StOpt_ROOT"
        cmake --build build
        cmake --install build
        mv "${INSTALL_ROOT}/doc" StOpt_ROOT # TODO remove when the doc bug in StOpt will be fixed
      else
        echo "StOpt already up to date."
      fi
      cd "$INSTALL_ROOT"
    fi
  fi

  echo "Installation completed successfully on Ubuntu."
}

# Default values indicating if CPLEX and Gurobi should be installed
# it works even if you use `install_cplex=0` or `install_gurobi=0`
install_cplex=${install_cplex:-1}
install_gurobi=${install_gurobi:-1}
install_smspp=${install_smspp:-1}
update_linux=${update_linux:-1}
install_scip=${install_scip:-1}
install_highs=${install_highs:-1}
install_stopt=${install_stopt:-1}
install_coin=${install_coin:-1}
no_interact=${no_interact:-1}
cplex_installer=""
gurobi_installer=""
gurobi_licence=""

# Default value for installation and compilation root
# after install build_root can be deleted
install_root=""
build_root=""

# Parse command line 
echo "arguments $@"
for arg in "$@"
do
  case $arg in
	--without-linux-update)  # prevents update of linux packages
    update_linux=0
    shift
    ;;
    --without-cplex)
    install_cplex=0
    shift
    ;;	
	--without-scip)
    install_scip=0
    shift
    ;;
	--without-highs)
    install_highs=0
    shift
    ;;
	--without-stopt)
    install_stopt=0
    shift
    ;;
	--without-coin)  # mainly for cases with coin already installed
    install_coin=0
    shift
    ;;
    --without-gurobi)
    install_gurobi=0
    shift
    ;;
	--without-smspp)
    install_smspp=0
    shift
    ;;
	--without-interact)
    no_interact=0
    shift
    ;;
    --install-root=*)
    install_root="${arg#*=}"
    shift
    ;;
	--build-root=*)
    build_root="${arg#*=}"
    shift
    ;;
	--cplex-installer=*)
    cplex_installer="${arg#*=}"
    shift
    ;;
	--gurobi-installer=*)
    gurobi_installer="${arg#*=}"
    shift
    ;;
	--gurobi-licence=*)
    gurobi_licence="${arg#*=}"
    shift
    ;;
    *)
    ;;
  esac
done

# Detect operating system and execute the appropriate installation function
OS="$(uname)"
case "$OS" in
"Linux")
  if [ -f /etc/os-release ]; then
    . /etc/os-release
	echo "ditrib: $ID"
	if [ "$ID" = "ubuntu" ] || [ "$ID" = "debian" ]; then
	  # Check if the user has sudo access
	  # why is the 
		if sudo -n true 2>/dev/null; then
			HAS_SUDO=1
			INSTALL_ROOT="${install_root:-/opt}"
			BUILD_ROOT="${build_root:-/opt}"
			SMSPP_ROOT="${INSTALL_ROOT}/smspp-project"
		else
			HAS_SUDO=0
			INSTALL_ROOT="${install_root:-${HOME}}"
			BUILD_ROOT="${build_root:-${HOME}}"
			SMSPP_ROOT="${HOME}/smspp-project"  # why not ${INSTALL_ROOT}/smspp-project?
		fi
		
		# create dirs if they do not exist
		if [ ! -d $INSTALL_ROOT ]; then mkdir $INSTALL_ROOT; fi
		if [ ! -d $BUILD_ROOT ]; then mkdir $BUILD_ROOT; fi
		
		# copy cplex and gurobi installers to the installation dir
		if [ ! "${cplex_installer}" = "" ]; then
			if [ -f ${cplex_installer} ]; then
				cp ${cplex_installer} $INSTALL_ROOT
			fi
		fi
		if [ ! "${gurobi_installer}" = "" ]; then
			if [ -f ${gurobi_installer} ]; then
				cp ${gurobi_installer} $INSTALL_ROOT
			fi
		fi
		if [ ! "${gurobi_licence}" = "" ]; then
			if [ -f ${gurobi_licence} ]; then
				cp ${gurobi_licence} $INSTALL_ROOT
			fi
		fi

		# I want to build and install in different dirs so I add these variables
		# which I use insteas of SMSPP_ROOT
		SMSPP_BUILD_ROOT="${BUILD_ROOT}/smspp-project"
		SMSPP_INSTALL_ROOT="${INSTALL_ROOT}/sms++"
	  install_on_linux
	else
	  echo "This script supports Ubuntu only."
	  exit 1
	fi
  else
    echo "This script supports Debian-based Linux distros only."
    exit 1
  fi
  ;;
"Darwin")
  INSTALL_ROOT="${install_root:-/Library}"
  SMSPP_ROOT="${INSTALL_ROOT}/smspp-project"
  install_on_macos
  ;;
*)
  echo "This script does not support the detected operating system."
  exit 1
  ;;
esac

# Skip compilation if running in a GitLab CI/CD Docker container
if ! { [ -f /.dockerenv ] && [ "$CI" = "true" ]; }; then
  # Install SMSpp
  echo "Compiling SMSpp..."
  SMSPP_URL=https://github.com/plan4resDev/Umbrella.git
  smsbranch=plan4res
  
  cd $BUILD_ROOT
  # Check if the SMSpp repository already exists
  if [ -d "$SMSPP_BUILD_ROOT" ]; then
    cd $SMSPP_BUILD_ROOT
    echo "SMSpp already exists. Pulling latest changes..."
    git pull
  else
    echo "Repository not found locally. Cloning SMSpp..."
	if [ -z "$DISPLAY" ] || [ ! -t 1 ] || [ "$no_interact" -eq 1 ] ; then 
		git clone --branch $smsbranch --recurse-submodules $SMSPP_URL "$SMSPP_BUILD_ROOT"
		cd $SMSPP_BUILD_ROOT
		git submodule foreach --recursive '
			if git show-ref --verify --quiet refs/heads/$smsbranch; then
				git checkout $smsbranch
			fi
			'
	else
		git clone --branch $smsbranch $SMSPP_URL "$SMSPP_BUILD_ROOT"
	fi
  fi
  cd $SMSPP_BUILD_ROOT

  # If the installation root is not the default one, update the makefile-paths
  echo "build in $SMSPP_BUILD_ROOT and install in $SMSPP_INSTALL_ROOT"
  if [[ ("$OS" == "Linux" && "$INSTALL_ROOT" != "/opt") ||
        ("$OS" == "Darwin" && "$INSTALL_ROOT" != "/Library") ]]; then
    umbrella_extlib_file="$SMSPP_BUILD_ROOT/extlib/makefile-paths"
    # Create the file with the new paths of the resources for the umbrella
    {
      echo "CPLEX_ROOT = ${CPLEX_ROOT}"
      echo "SCIP_ROOT = ${SCIP_ROOT}"
      echo "GUROBI_ROOT = ${GUROBI_ROOT}"
      echo "HiGHS_ROOT = ${HiGHS_ROOT}"
      echo "StOpt_ROOT = ${StOpt_ROOT}"
      echo "CoinUtils_ROOT = ${CoinOr_ROOT}"
      echo "Osi_ROOT = ${CoinOr_ROOT}"
      echo "Clp_ROOT = ${CoinOr_ROOT}"
    } > "$umbrella_extlib_file"
    echo "Created $umbrella_extlib_file file."

    # If the submodule BundleSolver is initialized, i.e., the folder is not empty
    if [ -d "$SMSPP_BUILD_ROOT/BundleSolver" ] && [ -n "$(ls -A "$SMSPP_BUILD_ROOT/BundleSolver")" ]; then
      ndofi_extlib_file="$SMSPP_BUILD_ROOT/BundleSolver/NdoFiOracle/extlib/makefile-paths"
      # Create the file with the new paths of the resources for BundleSolver/NdoFiOracle
      {
        echo "CPLEX_ROOT = ${CPLEX_ROOT}"
        echo "GUROBI_ROOT = ${GUROBI_ROOT}"
        echo "CoinUtils_ROOT = ${CoinOr_ROOT}"
        echo "Osi_ROOT = ${CoinOr_ROOT}"
        echo "Clp_ROOT = ${CoinOr_ROOT}"
      } > "$ndofi_extlib_file"
      echo "Created $ndofi_extlib_file file."
    fi

    # If the submodule MCFBlock is initialized, i.e., the folder is not empty
    if [ -d "$SMSPP_BUILD_ROOT/MCFBlock" ] && [ -n "$(ls -A "$SMSPP_BUILD_ROOT/MCFBlock")" ]; then
      mcf_extlib_file="$SMSPP_BUILD_ROOT/MCFBlock/MCFClass/extlib/makefile-paths"
      # Create the file with the new paths of the resources for the MCFBlock/MCFClass
      {
        echo "CPLEX_ROOT = ${CPLEX_ROOT}"
      } > "$mcf_extlib_file"
      echo "Created $mcf_extlib_file file."
    fi
  fi

  # Build SMSpp
  cd $SMSPP_BUILD_ROOT
  if [ -z "$DISPLAY" ] || [ ! -t 1 ] || [ "$no_interact" -eq 1 ]; then
	  CMAKEFLAGS="-DCMAKE_INSTALL_PREFIX=${SMSPP_INSTALL_ROOT} 
		-Wno-dev \
		-DBOOST_ROOT=${BOOST_PATH} \
		-DEigen3_ROOT=${EIGEN_PATH}/share/eigen3/cmake \
		-DStOpt_ROOT=${StOpt_ROOT} \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_InvestmentBlock \
		-DBUILD_tools \
		-DBUILD_LagrangianDualSolver=ON \
		-DBUILD_BundleSolver=ON \
		-DBUILD_MILPSolver=ON "
	cmake -S . -B build $CMAKEFLAGS
	echo "make 2"
	cmake --build build
	echo "make3"
	cmake --install build --prefix ${SMSPP_INSTALL_ROOT}
  else
	# run ccmake in a xterm subshell to allow interaction
    xterm -e ccmake build & # select submodules, then Configure and Generate the build files
    wait $! # wait for ccmake to finish
    CCMAKE_EXIT_CODE=$?
    if [ $CCMAKE_EXIT_CODE -eq 0 ]; then
      cmake --build build
      cmake --install build
      #cd build
      #ctest -V
      #cd "$SMSPP_ROOT"
    else
      echo "ccmake fails with exit code $CCMAKE_EXIT_CODE."
      exit 1
    fi
  fi
  

fi
