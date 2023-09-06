#git config --global user.name "JaewooJoung" 
#git config --global user.email "jaewoo.joung@outlook.com" 
#git config --list # 계정확인
#cd d: #로컬 위치
#git clone https://github.com/JaewooJoung/julia
#git pull origin main
using Dates

my_message = "push git push"

repo_path = "/home/jaewoo/Documents/migit/markdown"
cd(repo_path)
run(`git add .`)
dt=now()
commit_message = Dates.format(dt, "yyyymmddHHMMSS ") * my_message
run(`git commit -m $commit_message`)
run(`git pull --rebase`)
run(`git push --all`)

#change
#=
cd C:\JDrive\TATA\GITATA\TATA
git add .
git commit -m "%1"
git push --all
=#