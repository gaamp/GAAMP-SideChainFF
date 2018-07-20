#!/bin/sh
if [ "$#" -eq 6 ]; then
  Idx_H=$4
  Is_L_Ca=$5
  if [ "$6" = "Ini_CGenFF_Match" ]; then
      Ini_CGenFF_Match=1
      Ini_CGenFF_Server=0
      Ini_GAFF=0
  elif [ "$6" = "Ini_CGenFF_Server" ]; then
      Ini_CGenFF_Match=0
      Ini_CGenFF_Server=1
      Ini_GAFF=0
  else 
      Ini_CGenFF_Match=0
      Ini_CGenFF_Server=0
      Ini_GAFF=1
  fi
else
  echo "Usage: getcharge.sh mol.pdb pdb/mol2 netcharge Idx_H Is_L_Ca Ini_CgenFF"
  exit 1
fi


# For test only !!!
#cat >  QM-para.txt << EOF
#QM_LEVEL_1D_SCAN   "#HF/6-31G* nosymm opt=ModRedundant\n\n"
#
#EOF

###Chetan: loads all the dependencies as defined by the users rather than in the script itself
source ./non-polar-aa-new/opt/PATHS 

#mem_per_core="32GB"
#ncore="16"
#serverdir="./non-polar-aa-new/exe/" 

#G09_EXE_PATH="/homes/huanglei/prog/g09/g09"
#GAUSS_EXEDIR="/homes/huanglei/prog/g09"
#AMBERHOME="/home/huanglei/tools/amber11"
#babelhome="/home/huanglei/tools/openbabel-install"
#mpirun="mpiexec -np $ncore"

To_Fit_E_Wat=1

# Set the netcharge of the compound
NetCharge=$3
# Do torsion parameter fitting
TorsionFitting=1



workdir=`pwd`
/bin/date > time-1.txt


cat >> fit-mol.conf << EOF

# This is the weight in ESP calculations for those grid points around H donor/acceptor in H-bond
w_H_Donor_Acceptor  1.0
# This is the weight of compound-water interaction energies
w_water_E_min       0.2
w_water_R_min       8.0
### End   weights used for fitting. May need change!!!

EOF

cat >> fit-mol.conf << EOF
FILE_FORCE_FIELD    mol.prm
FILE_PSF            mol.xpsf
FILE_CRD            mol-opt.crd
FILE_pot0           mol-esp.dat

FILE_MolWater_PSF   mol-wat.xpsf
FILE_MolWaterEnergy E-mol-wat.txt

EOF


cat > mypath.txt << EOF
G09_EXE_PATH           $G09_EXE_PATH
CGRID_EXE_PATH         $serverdir/non-polar-ff/exe/cgrid
CGRID_DRUDE_EXE_PATH   $serverdir/drude-ff/exe/cgrid
EOF


cat >> QM-para.txt << EOF
###### Start parameters to Gaussian. May need change!!!
QM_MEM        $mem_per_core
QM_NPROC      $ncore
###### End   parameters to Gaussian. May need change!!!

QM_LEVEL_OPT  "#HF/6-31G* opt\n\n"
QM_LEVEL_DIMER_OPT  "#HF/6-31G* nosymm SCF=Tight opt(Z-MATRIX,MaxCycles=200)\n\n"
QM_LEVEL_ESP  "#HF/6-31G* nosymm scf=tight \nprop=(read,field)\n\n"
QM_LEVEL_ESP_DRUDE  "#B3LYP/aug-cc-pVDZ nosymm scf=tight prop=(read,field)\n\n"
QM_LEVEL_E_DIMER  "#HF/6-31G* nosymm\n\n"
QM_LEVEL_E_MONOMER "#HF/6-31G* nosymm SCF=Tight"
QM_LEVEL_ROTAMER   "#HF/6-31G* nosymm opt(MaxCycles=100)\n\n"
EOF


export PATH=$GAUSS_EXEDIR:$PATH
export GAUSS_EXEDIR=$GAUSS_EXEDIR
export GAUSS_SCRDIR=$TMPDIR
export AMBERHOME=$AMBERHOME

FileType=$2
FileName=$1

dirname=`grep "dirname" ./fit-mol.conf | awk '{print $2}'`

Finish ()
{
  cd $workdir
  
  cd result
  cp $serverdir/non-polar-aa/par_all27_prot_na.prm .
  cp $serverdir/non-polar-aa/top_all27_prot_na.rtf .
  $serverdir/non-polar-aa/exe/merge-charmm
  cp ../06-full/full-opt.pdb .
  cd ..

  /bin/date > time-2.txt

cat >  ./result/readme.txt << EOF
aa.rtf           - The toppar file to be used
aa.prm           - The toppar file to be used
top_all27_prot_na.rtf - CHARMM 27 force field with aa.rtf merged
par_all27_prot_na.prm - CHARMM 27 force field with aa.prm merged

report-esp.txt   - The result of ESP charge fitting for side chain molecule
report-esp-wat.txt - The result of charge fitting with ESP and water-compound interactions for side chain molecule
result-1D.html     - The result of 1D energy profiles after 1D torsion fitting
fitting-1d-*.dat   - The 1D energy profile for a soft dihedral after 1D torsion fitting. Format: phi, E_QM, E_MM

qm               - The directory containing all QM data used in parameter fitting
qm/qm-mol-opt.out - The Gaussian output of QM geometry optimization
qm/qm-mol-esp.out - The Gaussian output of QM electrostatic potential used for non-polarizable model
qm/qm-mol-wat-donor*.out - The Gaussian output of the QM calculation to determine Emin and Rmin for a H donor interacting with a water molecule
qm/qm-mol-wat-donor*.pdb - The snapshot in which the pose of a water is optimized in QM for a H donor interacting with a water molecule
qm/qm-mol-wat-acceptor*.out - The Gaussian output of the QM calculation to determine Emin and Rmin for a H acceptor interacting with a water molecule
qm/qm-mol-wat-acceptor*.pdb - The snapshot in which the pose of a water is optimized in QM for a H acceptor interacting with a water molecule
qm/qm-1d-phi-*.out  - The Gaussian output of QM 1D torsion scan for a specific soft dihedral
qm/qm-rotamer-*.out - The Gaussian output of QM geometry optimization for a specific rotamer

mm-acceptor-*.pdb   - The snapshot in which the pose of a water is optimized in MM for a H acceptor interacting with a water molecule
mm-donor-*.pdb      - The snapshot in which the pose of a water is optimized in MM for a H donor interacting with a water molecule

full-opt.pdb        - A snapshot of the side-chain molecule bonded with peptide backbone

EOF


  mkdir bak-result
  mv result/sc*  ./bak-result/
  mv result/mol* ./bak-result/
  
  /bin/tar --exclude="*.sh" --exclude="*.log" -zcvf result.tgz ./result 
  chmod a+r result.tgz
#  /usr/bin/python $serverdir/mol-search/plot-mol-2d.py $FileType $FileName  > log-gen-2d-img.txt 2>&1
#  $serverdir/mol-search/mol_info $FileName  > log-gen-mol-info.txt 2>&1
  chmod a+r *.png
  #/bin/bash ./sendemail.sh
  echo "Finish."

 
  # To make sure the email is sent out. 
  #sleep 5
  
  #mkdir ../../database/$dirname
  #mv ../$dirname/* ../../database/$dirname/

  #cd ../../database/$dirname/
  #export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$serverdir/mol-search/tr2-1.02/build
  #$serverdir/mol-search/tr2-1.02/my_Mol_Search/client + /fusion/gpfs/home/huanglei/web-server/pub-data/database/$dirname/ > add-mol.log 2>&1
  
  exit 0
}

ErrorQuit ()
{
  cd $workdir
  echo "Quit parameterization due to errors." >> ./email.txt
  /bin/date > time-2.txt
  /bin/tar --exclude="*.sh" --exclude="*.log" -zcvf result.tgz ./result 
  chmod a+r result.tgz
  #/bin/bash ./sendemail.sh
  exit 1
}


RefitCharge ()
{
  if [ -e ../05-fitting-esp-wat/E-mol-wat.txt ]; then
    cd ..
    cp -R 05-fitting-esp-wat 05-fitting-esp-wat-refit
    cd 05-fitting-esp-wat-refit
    cp ../sc-14-1d-fitting/soft-dih-list.txt .
    cp ../sc-14-1d-fitting/saved-para.dat .
    cp para-check.dat para-opt-start.dat
    
    $serverdir/non-polar-ff/exe/fitcharge-again fit-mol.conf > run-fitcharge.log
    retcode=$?
    if [ "$retcode" -ne 0 ]; then
      echo "Error in fitcharge. Quit." >> ../email.txt
      ErrorQuit
    fi
    
    $serverdir/non-polar-ff/exe/update-xpsf
    retcode=$?
    if [ "$retcode" -ne 0 ]; then
      echo "Error in update-xpsf. Quit." >> ../email.txt
      ErrorQuit
    fi
    
    mv ../05-fitting-esp-wat ../05-fitting-esp-wat-old
    cp -R ../05-fitting-esp-wat-refit ../05-fitting-esp-wat
    cd ../05-fitting-esp-wat
  fi
}



#########################  Start running the job
mkdir 01-ac
cd 01-ac

## to convert user's file to Gaussian input for semi-empirical optimization
if [ "$2" = "pdb" ] 
then
   $babelhome/bin/babel -ipdb ../$1 -ogjf mol.gjf
else
   $babelhome/bin/babel -imol2 ../$1 -ogjf mol.gjf
fi

retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in converting user's pdb/mol2 file into Gaussian input file with OpenBabel. Quit." >> ../email.txt
  ErrorQuit
fi

linenum=`wc -l mol.gjf | awk '{print $1}'`

#echo "%nproc=2" > mol-opt.gjf
echo "%mem=4GB" >> mol-opt.gjf
#echo "# opt=cartesian ram1 " >> mol-opt.gjf
echo "# opt ram1 " >> mol-opt.gjf
echo " " >> mol-opt.gjf
echo "Mol " >> mol-opt.gjf
echo " " >> mol-opt.gjf
echo "$NetCharge 1" >> mol-opt.gjf
leftline=`expr $linenum - 5`
tail -n $leftline mol.gjf >> mol-opt.gjf
g09 < mol-opt.gjf > mol-opt-00.out
$babelhome/bin/babel -ig09 mol-opt-00.out -omol2 mol-opt.mol2
$babelhome/bin/babel -ig09 mol-opt-00.out -opdb mol-opt.pdb

retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in geometry optimization with semi-empirical method or converting Gaussian output into mol2 file with OpenBabel. Quit." >> ../email.txt
  ErrorQuit
fi

if [ "$Ini_GAFF" -eq 1 ]; then
  $AMBERHOME/bin/antechamber -i mol-opt.mol2 -fi mol2 -o mol -fo charmm -j both -c bcc -at gaff -nc $NetCharge
  retcode=$?
  if [ "$retcode" -ne 0 ]; then
    echo "Error in antechamber. Quit." >> ../email.txt
    ErrorQuit
  fi
fi

if [ "$Ini_CGenFF_Match" -eq 1 ]; then
  export PerlChemistry=$serverdir/MATCH_RELEASE/PerlChemistry
  export MATCH=$serverdir/MATCH_RELEASE/MATCH

  cp mol-opt.pdb mol.pdb
  $MATCH/scripts/MATCH.pl -forcefield top_all36_cgenff mol.pdb > log_match.txt
  retcode=$?
  if [ "$retcode" -ne 0 ]; then
    echo "Error in MATCH.pl. Quit." >> ../email.txt
    ErrorQuit
  fi
  Success=`grep "Success" log_match.txt | wc -l`
  if [ "$Success" -eq 0 ]; then
    echo "Error in MATCH.pl. Quit." >> ../email.txt
    ErrorQuit
  fi
fi

if [ "$Ini_CGenFF_Server" -eq 1 ]; then
  USER_IP=`head -n 1 ../info_cgenff.txt | awk '{print $1}'`
  USER_EMAIL=`head -n 1 ../info_cgenff.txt | awk '{print $2}'`
  echo "# USER_IP $USER_IP USER_LOGIN $USER_EMAIL INTERFACE GAAMP" > server.mol2
  cat mol-opt.mol2 >> server.mol2
  nc dogmans.umaryland.edu 32108 < server.mol2 > cgenff.txt
  nline=`wc -l cgenff.txt | awk '{print $1}'`
  if [ "$nline" -lt 5 ]; then
    sleep 5
      
    nc dogmans.umaryland.edu 32109 < server.mol2 > cgenff.txt
    nline=`wc -l cgenff.txt | awk '{print $1}'`
    if [ "$nline" -lt 5 ]; then
      echo "Error in getting FF from Alex's server. Quit." >> ../email.txt
      ErrorQuit
    fi
  fi
  $serverdir/non-polar-ff/exe/prep_cgenff cgenff.txt $serverdir/non-polar-ff/top_all36_cgenff.rtf $serverdir/non-polar-ff/par_all36_cgenff.prm $NetCharge > log_prep_cgenff.txt
  if [ "$retcode" -ne 0 ]; then
    echo "Error in prep_cgenff. Quit." >> ../email.txt
    ErrorQuit
  fi
fi

$serverdir/non-polar-ff/exe/equiv_atom mol.rtf > log_equiv_atom.txt
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in equiv_atom. Quit." >> ../email.txt
  ErrorQuit
fi

$serverdir/non-polar-ff/exe/exclude_H2 $Idx_H

cat equiv-mod.txt >> ../fit-mol.conf
echo "fix   $Idx_H   0.0" >> ../fit-mol.conf

cp mol.rtf org-mol.rtf
cp mol.prm org-mol.prm

$serverdir/non-polar-ff/exe/add-tip3 mol.rtf mol.prm $NetCharge
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in add-tip3. Quit." >> ../email.txt
  ErrorQuit
fi

$serverdir/non-polar-ff/exe/gen_xpsf mol.rtf mol.xpsf MOL > log_gen_xpsf.txt
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in gen_xpsf MOL. Quit." >> ../email.txt
  ErrorQuit
fi
$serverdir/non-polar-ff/exe/gen_xpsf mol.rtf mol-wat.xpsf MOL TIP3 > log_gen_xpsf_tip3.txt
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in gen_xpsf MOL TIP3. Quit." >> ../email.txt
  ErrorQuit
fi

$serverdir/non-polar-ff/exe/pdb_to_crd 
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in pdb_to_crd. Quit." >> ../email.txt
  ErrorQuit
fi


mkdir ../02-esp
cp ./mol* ../02-esp/
cd ../02-esp

$serverdir/non-polar-ff/exe/gen-esp mol.inp mol.xpsf $NetCharge > gen-esp.log
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in gen-esp. Quit." >> ../email.txt
  ErrorQuit
fi

cp mol-opt.out qm-mol-opt.out
cp cal-esp.out qm-mol-esp.out

$serverdir/non-polar-ff/exe/check-b0-theta0 > check-b0-theta0.log
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in check-b0-theta0. Quit." >> ../email.txt
  ErrorQuit
fi


mkdir ../03-fitting-esp
cp mol*.xpsf ../03-fitting-esp
cp mol.prm ../03-fitting-esp
cp mol.rtf ../03-fitting-esp
cp mol-esp.dat ../03-fitting-esp
cp mol-opt.crd ../03-fitting-esp
cp elem-list.txt ../03-fitting-esp
cd ../03-fitting-esp
cp ../fit-mol.conf ./

/bin/grep "    X= " ../02-esp/cal-esp.out | /usr/bin/head -n 1 | /bin/awk '{print "DIPOLE_QM " $2 "  "  $4 "   " $6 "   " $8}' >> fit-mol.conf

$serverdir/non-polar-ff/exe/fitcharge fit-mol.conf > run-fitcharge.log
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in fitcharge. Quit." >> ../email.txt
  ErrorQuit
fi

$serverdir/non-polar-ff/exe/update-xpsf
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in update-xpsf. Quit." >> ../email.txt
  ErrorQuit
fi

mkdir ../result
mkdir ../result/qm
cp final-para.txt ../result/report-esp.txt
cp mol.prm ../result/
cp mol-esp.rtf ../result/
cp ../02-esp/mol-opt.crd ../result/
mv ../02-esp/qm-mol-opt.out ../result/qm/
mv ../02-esp/qm-mol-esp.out ../result/qm/
cp ../$FileName ../result/


if [ "$To_Fit_E_Wat" -eq 1 ]; then
  mkdir ../04-H-bond
  cp cg-list.txt ../04-H-bond/
  cp elem-list.txt ../04-H-bond/
  cp mol-opt.crd ../04-H-bond/
  cp mol*.xpsf ../04-H-bond/
  cp mol.prm ../04-H-bond/
  
  
  if [ -e ../01-ac/equiv-org.txt ]; then
    cp ../01-ac/equiv-org.txt ../04-H-bond/
  else
    grep "^equivalent" ../fit-mol.conf > ../04-H-bond/equiv-org.txt
  fi
  
  cd ../04-H-bond/
  $serverdir/non-polar-ff/exe/acceptor mol-opt.crd > run-acceptor.log
  retcode=$?
  if [ "$retcode" -ne 0 ]; then
    echo "Error in acceptor. Quit." >> ../email.txt
    ErrorQuit
  fi
  
  $serverdir/non-polar-ff/exe/donor mol-opt.crd > run-donor.log
  retcode=$?
  if [ "$retcode" -ne 0 ]; then
    echo "Error in donor. Quit." >> ../email.txt
    ErrorQuit
  fi
  
  /usr/bin/python $serverdir/extract-qm-mol-water.py > log-extract-qm-mol-wat.txt 
  mv qm-mol-wat-* ../result/qm/
  
  if [ -e ./E-mol-wat.txt ]; then
    mkdir ../05-fitting-esp-wat
    cd ../05-fitting-esp-wat
    cp ../03-fitting-esp/mol*.xpsf ./
    cp ../03-fitting-esp/mol.prm ./
    cp ../03-fitting-esp/mol.rtf ./
    cp ../03-fitting-esp/mol-esp.dat ./
    cp ../03-fitting-esp/mol-opt.crd ./
    cp ../03-fitting-esp/elem-list.txt ./
    cp ../03-fitting-esp/fit-mol.conf ./
    cp ../03-fitting-esp/para-check.dat ./para-opt-start.dat
    cp ../04-H-bond/E-mol-wat.txt ./
    
    echo "Target_E_Int_Water" >> fit-mol.conf
  
    echo "SCALE_QM_E_MIN          1.16" >> fit-mol.conf
    echo "SHIFT_QM_R_MIN         -0.20" >> fit-mol.conf
    echo "SHIFT_QM_R_MIN_CHARGED -0.20" >> fit-mol.conf
    
    $serverdir/non-polar-ff/exe/fitcharge fit-mol.conf > run-fitcharge.log
    retcode=$?
    if [ "$retcode" -ne 0 ]; then
      echo "Error in fitcharge. Quit." >> ../email.txt
      ErrorQuit
    fi
    
    $serverdir/non-polar-ff/exe/update-xpsf
    retcode=$?
    if [ "$retcode" -ne 0 ]; then
      echo "Error in update-xpsf. Quit." >> ../email.txt
      ErrorQuit
    fi
    
    
    cp final-para.txt ../result/report-esp-wat.txt
    cp mol-esp.rtf ../result/mol-esp-wat.rtf
    cp *.pdb ../result/


    mkdir ../sc-10-torsion-detect-soft-torsion
    cd ../sc-10-torsion-detect-soft-torsion

    cp ../05-fitting-esp-wat/mol.prm .
    cp ../05-fitting-esp-wat/new-mol.xpsf ./mol.xpsf
    cp ../05-fitting-esp-wat/mol-opt.crd .

    $serverdir/non-polar-ff/exe/gen_soft_list > run.log
    retcode=$?
    if [ "$retcode" -ne 0 ]; then
      echo "Error in gen_soft_list. Quit." >> ../email.txt
      ErrorQuit
    fi

    NumTorsion=`wc -l soft-dih-list.txt | awk '{print $1}'`

    if [ "$NumTorsion" -eq 1 ]; then
      mkdir ../sc-12-qm-1d-scan
      cp mol.prm ../sc-12-qm-1d-scan/
      cp mol.xpsf ../sc-12-qm-1d-scan/
      cp mol-opt.crd ../sc-12-qm-1d-scan/
      cp soft-dih-list.txt ../sc-12-qm-1d-scan/
      cd ../sc-12-qm-1d-scan
      cp ../02-esp/elem-list.txt .
      
      cp $serverdir/non-polar-ff/exe/qm-1d-scan-single .
  
      ./qm-1d-scan-single > log-qm-1d.txt
      retcode=$?
      if [ "$retcode" -ne 0 ]; then
        echo "Error in qm-1d-scan-single. Quit." >> ../email.txt
        ErrorQuit
      fi

#      cp qm-1d-phi-*.out ../result/qm/

      mkdir ../sc-14-1d-fitting
      cd ../sc-14-1d-fitting
      cp ../sc-12-qm-1d-scan/mol.prm .
      cp ../sc-12-qm-1d-scan/mol.xpsf .
      cp ../sc-12-qm-1d-scan/tor-1D-idx-*.dat .
      cp ../sc-12-qm-1d-scan/soft-dih-list.txt .

      $serverdir/non-polar-ff/exe/1d-fitting > log-1d-fitting.txt
      retcode=$?
      if [ "$retcode" -ne 0 ]; then
        echo "Error in 1d-fitting. Quit." >> ../email.txt
        ErrorQuit
      fi
  
      head -n 1 torsion-para-1.dat > saved-para.dat
  
      RefitCharge
    elif [ "$NumTorsion" -gt 1 ]; then
      mkdir ../sc-11-mm-pes
      cp mol.prm ../sc-11-mm-pes
      cp mol.xpsf ../sc-11-mm-pes
      cp mol-opt.crd ../sc-11-mm-pes
      cp soft-dih-list.txt ../sc-11-mm-pes
      cd ../sc-11-mm-pes

      $mpirun $serverdir/non-polar-ff/exe/mm_pes

      retcode=$?
      if [ "$retcode" -ne 0 ]; then
        echo "Error in mm_pes. Quit." >> ../email.txt
        ErrorQuit
      fi

      cat mm-pes-id-*.dat > E-phi-mm-pes.txt
      $serverdir/non-polar-ff/exe/clustering-phi > log-clustering.txt
      retcode=$?
      if [ "$retcode" -ne 0 ]; then
        echo "Error in clustering-phi. Quit." >> ../email.txt
        ErrorQuit
      fi

      rm opt-*.pdb

      mkdir ../sc-12-qm-1d-scan
      cp mol.prm ../sc-12-qm-1d-scan
      cp mol.xpsf ../sc-12-qm-1d-scan
      cp mol-opt.crd ../sc-12-qm-1d-scan
      cp soft-dih-list-new.txt ../sc-12-qm-1d-scan/soft-dih-list.txt
      cd ../sc-12-qm-1d-scan
      cp ../02-esp/elem-list.txt .
      
#      cp $serverdir/non-polar-ff/exe/qm-1d-scan .
#      ./qm-1d-scan > log-qm-1d.txt
      cp $serverdir/non-polar-ff/exe/qm-1d-scan-para .
      ./qm-1d-scan-para > log-qm-1d.txt

      retcode=$?
      if [ "$retcode" -ne 0 ]; then
        echo "Error in qm-1d-scan. Quit." >> ../email.txt
        ErrorQuit
      fi

      mkdir ../sc-14-1d-fitting
      cd ../sc-14-1d-fitting
      cp ../sc-12-qm-1d-scan/mol.prm .
      cp ../sc-12-qm-1d-scan/mol.xpsf .
      cp ../sc-12-qm-1d-scan/tor-1D-idx-*.dat .
      cp ../sc-12-qm-1d-scan/soft-dih-list.txt .
      $serverdir/non-polar-ff/exe/1d-fitting > log-1d-fitting.txt
      retcode=$?
      if [ "$retcode" -ne 0 ]; then
        echo "Error in 1d-fitting. Quit." >> ../email.txt
        ErrorQuit
      fi

      rm -Rf saved-para.dat
      touch saved-para.dat
      IdxTor=1
      while [  $IdxTor -le $NumTorsion ]; do
          head -n 1 torsion-para-${IdxTor}.dat >> saved-para.dat
          let IdxTor=IdxTor+1 
      done

      RefitCharge
    else
      echo "There is no soft dihedrals in side chain molecule."
    fi
    
    
#    echo "Finish the fitting targetting ESP and compound-water interactions."
  fi
fi

cd ../result
cp mol.prm sc.prm
cp mol-esp.rtf sc.rtf
cp ../02-esp/elem-list.txt sc-elem-list.txt
cp ../03-fitting-esp/new-mol.xpsf sc.xpsf
if [ -e mol-esp-wat.rtf ]; then
  cp mol-esp-wat.rtf sc.rtf
  cp ../05-fitting-esp-wat/new-mol.xpsf sc.xpsf
fi


cd ..

mkdir 06-full
cd 06-full
cp ../result/sc.prm .
cp ../result/sc.rtf .
cp ../result/sc.xpsf .
cp ../result/mol-opt.crd sc.crd
cp ../result/sc-elem-list.txt .

cp $serverdir/non-polar-aa/data/* .


if [ "$Ini_GAFF" -ne 1 ]; then
  cp ../01-ac/mol-opt.pdb org-mol.pdb 
  $serverdir/non-polar-aa/exe/cap_methyl org-mol.pdb $Idx_H > log_cap_methyl.txt
  retcode=$?
  if [ "$retcode" -ne 0 ]; then
    echo "Error in cap_methyl. Quit." >> ../email.txt
    ErrorQuit
  fi
  
  if [ "$Ini_CGenFF_Match" -eq 1 ]; then
    export PerlChemistry=$serverdir/MATCH_RELEASE/PerlChemistry
    export MATCH=$serverdir/MATCH_RELEASE/MATCH

    $MATCH/scripts/MATCH.pl -forcefield top_all36_cgenff methyl_mol.pdb > log_match.txt
    retcode=$?
    if [ "$retcode" -ne 0 ]; then
      echo "Error in MATCH.pl for methyl_mol.pdb. Quit." >> ../email.txt
      ErrorQuit
    fi
    Success=`grep "Success" log_match.txt | wc -l`
    if [ "$Success" -eq 0 ]; then
      echo "Error in MATCH.pl for methyl_mol.pdb. Quit." >> ../email.txt
      ErrorQuit
    fi
  fi

  if [ "$Ini_CGenFF_Server" -eq 1 ]; then
    $babelhome/bin/babel -ipdb methyl_mol.pdb -omol2 methyl_mol.mol2
    retcode=$?
    if [ "$retcode" -ne 0 ]; then
      echo "Error in converting user's methyl_mol.pdb into methyl_mol.mol2 with OpenBabel. Quit." >> ../email.txt
      ErrorQuit
    fi

    USER_IP=`head -n 1 ../info_cgenff.txt | awk '{print $1}'`
    USER_EMAIL=`head -n 1 ../info_cgenff.txt | awk '{print $2}'`
    echo "# USER_IP $USER_IP USER_LOGIN $USER_EMAIL INTERFACE GAAMP" > server.mol2
    cat methyl_mol.mol2 >> server.mol2
    nc dogmans.umaryland.edu 32108 < server.mol2 > cgenff.txt
    nline=`wc -l cgenff.txt | awk '{print $1}'`
    if [ "$nline" -lt 5 ]; then
      sleep 5
      
      nc dogmans.umaryland.edu 32109 < server.mol2 > cgenff.txt
      nline=`wc -l cgenff.txt | awk '{print $1}'`
      if [ "$nline" -lt 5 ]; then
        echo "Error in getting FF for methyl_mol.mol2 from Alex's server. Quit." >> ../email.txt
        ErrorQuit
      fi
    fi
    $serverdir/non-polar-ff/exe/prep_cgenff cgenff.txt $serverdir/non-polar-ff/top_all36_cgenff.rtf $serverdir/non-polar-ff/par_all36_cgenff.prm $NetCharge > log_prep_cgenff.txt
    if [ "$retcode" -ne 0 ]; then
      echo "Error in prep_cgenff for methyl_mol.mol2. Quit." >> ../email.txt
      ErrorQuit
    fi
    mv mol.prm methyl_mol.prm
    mv mol.rtf methyl_mol.rtf
  fi
  
  $serverdir/non-polar-aa/exe/assemble_full $Idx_H $Is_L_Ca CGenFF > log-assemble-full.txt
else
  $serverdir/non-polar-aa/exe/assemble_full $Idx_H $Is_L_Ca GAFF > log-assemble-full.txt
fi

retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in assemble_full. Quit." >> ../email.txt
  ErrorQuit
fi

$serverdir/non-polar-ff/exe/gen_xpsf full.rtf full.xpsf MOL > log_gen_xpsf.txt
if [ ! -e full.xpsf ]; then
  echo "Fail to call gen_xpsf to generate full.xpsf. Quit! "
  ErrorQuit
fi

$serverdir/non-polar-aa/exe/opt_sc > log-opt-sc.txt
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in opt_sc. Quit." >> ../email.txt
  ErrorQuit
fi


######################  Start auto torsion fitting !!
mkdir ../10-torsion-detect-soft-torsion
cd ../10-torsion-detect-soft-torsion

cp ../06-full/full.prm ./mol.prm
cp ../06-full/full.xpsf ./mol.xpsf
cp ../06-full/mol-opt.crd .


$serverdir/non-polar-aa/exe/gen_soft_list_sc > run.log
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in gen_soft_list_sc. Quit." >> ../email.txt
  ErrorQuit
fi

NumTorsion=`wc -l soft-dih-list.txt | awk '{print $1}'`

if [ "$NumTorsion" -eq 0 ]; then
  echo "There is no soft dihedrals. Done. "
  cp ../06-full/full.rtf mol-tor.rtf
  $serverdir/non-polar-aa/exe/extract-aa-ff > extract-aa-ff.log
  retcode=$?
  if [ "$retcode" -ne 0 ]; then
    echo "Error in extract-aa-ff. Quit." >> ../email.txt
    ErrorQuit
  fi

  cp aa.rtf ../result/
  cp aa.prm ../result/

  Finish
elif [ "$NumTorsion" -gt 12 ]; then
  echo "There are $NumTorsion soft dihedrals. It is too expensive to proceed. Quit. "
  ErrorQuit
else
  echo "To do torsion fitting for $NumTorsion soft dihedrals."
fi


# swtich from g09 to g03 to make optimization more stable
# ELIOT => set back to g09 as g03 is no longuer working properly ???
cat > ../mypath.txt << EOF
G09_EXE_PATH           /homes/huanglei/prog/g09/g09
CGRID_EXE_PATH         $serverdir/non-polar-ff/exe/cgrid
CGRID_DRUDE_EXE_PATH   $serverdir/drude-ff/exe/cgrid
EOF

export PATH=/homes/huanglei/prog/g09:$PATH
export GAUSS_EXEDIR=/homes/huanglei/prog/g09
export GAUSS_SCRDIR=$TMPDIR
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/huanglei/lib

#sed "s/QM_NPROC      $ncore/QM_NPROC      6/g" ../QM-para.txt > 1.tmp
#mv 1.tmp ../QM-para.txt


if [ "$NumTorsion" -eq 1 ]; then
  echo "A single soft dihedral."

  mkdir ../12-qm-1d-scan
  cp mol.prm ../12-qm-1d-scan
  cp mol.xpsf ../12-qm-1d-scan
  cp mol-opt.crd ../12-qm-1d-scan
  cp soft-dih-list.txt ../12-qm-1d-scan/soft-dih-list.txt
  cd ../12-qm-1d-scan
  cp ../06-full/elem-full.txt elem-list.txt
  
  cp $serverdir/non-polar-aa/exe/qm-1d-scan-single_para ./
  ./qm-1d-scan-single_para > log-qm-1d.txt
  retcode=$?
  if [ "$retcode" -ne 0 ]; then
    echo "Error in qm-1d-scan-single_para. Quit." >> ../email.txt
    ErrorQuit
  fi
  
  cp qm-1d-phi-*.out ../result/qm/

  mkdir ../14-1d-fitting
  cd ../14-1d-fitting
  cp ../12-qm-1d-scan/mol.prm .
  cp ../12-qm-1d-scan/mol.xpsf .
  cp ../12-qm-1d-scan/tor-1D-idx-*.dat .
  cp ../12-qm-1d-scan/soft-dih-list.txt .

  $serverdir/non-polar-aa/exe/1d-fitting > log-1d-fitting.txt
  retcode=$?
  if [ "$retcode" -ne 0 ]; then
    echo "Error in 1d-fitting. Quit." >> ../email.txt
    ErrorQuit
  fi

  $serverdir/non-polar-ff/exe/plot-1d-result.sh

  mkdir bak
  cp mol.prm ./bak/
  cp mol.xpsf ./bak/
  cp ../06-full/full.rtf mol-tor.rtf
  cp ../06-full/full.rtf ./bak/mol-tor.rtf
  cp ../06-full/mol-opt.crd mol-opt.crd

  cp torsion-para-1.dat saved-para.dat
  $serverdir/non-polar-aa/exe/update-tor-para > update-tor-para.log
  retcode=$?
  if [ "$retcode" -ne 0 ]; then
    echo "Error in update-tor-para. Quit." >> ../email.txt
    ErrorQuit
  fi

  $serverdir/non-polar-aa/exe/extract-aa-ff > extract-aa-ff.log
  retcode=$?
  if [ "$retcode" -ne 0 ]; then
    echo "Error in extract-aa-ff. Quit." >> ../email.txt
    ErrorQuit
  fi

  
  cp aa.rtf ../result/
  cp aa.prm ../result/

  cp *.png ../result/
  cp result-1D.html ../result/
  cp fitting-1d-*.dat ../result/

  Finish
fi



mkdir ../11-mm-pes
cp mol.prm ../11-mm-pes
cp mol.xpsf ../11-mm-pes
cp mol-opt.crd ../11-mm-pes
cp soft-dih-list.txt ../11-mm-pes
cd ../11-mm-pes
$mpirun $serverdir/non-polar-aa/exe/mm_pes
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in mm_pes. Quit." >> ../email.txt
  ErrorQuit
fi


cat mm-pes-id-*.dat > E-phi-mm-pes.txt
$serverdir/non-polar-ff/exe/clustering-phi > log-clustering.txt
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in clustering-phi. Quit." >> ../email.txt
  ErrorQuit
fi

rm opt-*.pdb

mkdir ../12-qm-1d-scan
cp mol.prm ../12-qm-1d-scan
cp mol.xpsf ../12-qm-1d-scan
cp mol-opt.crd ../12-qm-1d-scan
cp soft-dih-list-new.txt ../12-qm-1d-scan/soft-dih-list.txt
cd ../12-qm-1d-scan
cp ../06-full/elem-full.txt elem-list.txt

cp $serverdir/non-polar-aa/exe/qm-1d-scan_para ./
./qm-1d-scan_para > log-qm-1d.txt

retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in qm-1d-scan. Quit." >> ../email.txt
  ErrorQuit
fi

cp qm-1d-phi-*.out ../result/qm/


mkdir ../14-1d-fitting
cd ../14-1d-fitting
cp ../12-qm-1d-scan/mol.prm .
cp ../12-qm-1d-scan/mol.xpsf .
cp ../12-qm-1d-scan/tor-1D-idx-*.dat .
cp ../12-qm-1d-scan/soft-dih-list.txt .
$serverdir/non-polar-aa/exe/1d-fitting > log-1d-fitting.txt
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in 1d-fitting. Quit." >> ../email.txt
  ErrorQuit
fi

$serverdir/non-polar-ff/exe/plot-1d-result.sh

cp *.png ../result/
cp result-1D.html ../result/
cp fitting-1d-*.dat ../result/

mkdir bak
cp mol.prm ./bak/
cp mol.xpsf ./bak/
cp ../06-full/full.rtf mol-tor.rtf
cp ../06-full/full.rtf ./bak/mol-tor.rtf
cp ../06-full/mol-opt.crd mol-opt.crd

rm -Rf saved-para.dat
touch saved-para.dat
IdxTor=1
while [  $IdxTor -le $NumTorsion ]; do
    head -n 1 torsion-para-${IdxTor}.dat >> saved-para.dat
    let IdxTor=IdxTor+1 
done


$serverdir/non-polar-aa/exe/update-tor-para > update-tor-para.log
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in update-tor-para. Quit." >> ../email.txt
  ErrorQuit
fi

$serverdir/non-polar-aa/exe/extract-aa-ff > extract-aa-ff.log
retcode=$?
if [ "$retcode" -ne 0 ]; then
  echo "Error in extract-aa-ff. Quit." >> ../email.txt
  ErrorQuit
fi


cp aa.rtf ../result/
cp aa.prm ../result/

cp *.png ../result/
cp result-1D.html ../result/
cp fitting-1d-*.dat ../result/

Finish
