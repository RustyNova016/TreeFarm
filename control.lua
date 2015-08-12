basechannel=666

modemSide= "right"
monitorSide = "left"

timeout = 2  -- CHECK IF BASE NEEDS UPDATES
jobtimeout = 2
treeChopTime = 25*60/2  -- 30 min

os.loadAPI("lain")
-- Specific program

-- Main base control
function TreeFarmControl(parentscreen, modem)
	modem.closeAll()

	if (parentscreen==nil) then
		parentscreen=term.current()
	end

	local w,h=parentscreen.getSize()
	local screen = window.create(parentscreen, 3,3,w-3,h-3,true )

	data = lain.readData("base.log")

	if (data==nil) then
		data={}

		-- initializing farm
		data.farm = {}
		data.farm.x = lain.ReadUserInput( screen, "Tree farm starting block x?",true)
		data.farm.y = lain.ReadUserInput( screen, "Tree farm starting block y?",true)
		data.farm.z = lain.ReadUserInput( screen, "Tree farm starting block z?",true)
		data.farm.f = lain.ReadUserInput( screen, "Tree farm starting block f?",true)

		data.farm.pLength = lain.ReadUserInput( screen, "Farm sector count forward?",true)
		data.farm.nLength = -lain.ReadUserInput( screen, "Farm sector count back?",true)

		data.farm.pWidth = lain.ReadUserInput( screen, "Farm sector count left?",true)
		data.farm.nWidth = - lain.ReadUserInput( screen, "Farm sector count right?",true)

		data.jcnt=0
		data.jobqueue={}

		data.tcnt=0
		data.turtle = {}
		data.time = 0

		-- Initializing chest location
		data.saplingcLocal = {
			x=2,
			y=0,
			z=1
		}
		data.fuelcLocal = {
			x=4,
			y=0,
			z=1
		}
		data.woodcLocal = {
			x=0,
			y=0,
			z=1
		}
		data.torchcLocal = {
			x=6,
			y=0,
			z=1
		}
		data.dirtcLocal = {
			x=8,
			y=0,
			z=1
		}
		data.saplingc=lain.taddCord(data.farm, data.saplingcLocal)
		data.fuelc=lain.taddCord(data.farm, data.fuelcLocal)
		data.woodc=lain.taddCord(data.farm, data.woodcLocal)
		data.torchc=lain.taddCord(data.farm, data.torchcLocal)
		data.dirtc=lain.taddCord(data.farm, data.dirtcLocal)

		-- Creating job list (jobs to do)
		for i=data.farm.nWidth,data.farm.pWidth do
			for j=data.farm.nLength,data.farm.pLength do
				print("A55 ",i," ",j)
				if (j~=0) then   -- BECAUSE 0 row dont exist
					local job1 = {
						id=data.jcnt,
						x=(i*3),
						y=2,
						z=(j*4),
						jobt=jobType.Dirt,
						nextjob=jobType.Sapling,
						time=data.time
					}
					data.jcnt =  data.jcnt+1
					table.insert(data.jobqueue, job1)
					local job2 = {
						id=data.jcnt,
						x=(i*3),
						y=2,
						z=(j*4) + ((j>0) and (1) or (-1)),
						jobt=jobType.Dirt,
						nextjob=jobType.Torch,
						time=data.time
					}
					data.jcnt =  data.jcnt+1
					table.insert(data.jobqueue, job2)
					local job3 = {
						id=data.jcnt,
						x=(i*3),
						y=2,
						z=(j*4) + ((j>0) and (2) or (-2)),
						jobt=jobType.Dirt,
						nextjob=jobType.Sapling,
						time=data.time
					}
					data.jcnt =  data.jcnt+1
					table.insert(data.jobqueue, job3)
				end
			end
		end

		print("saving installation data")
		lain.writeData("base.log",data)
	end

	modem.open(666) -- treefarm main channel

	local counter=os.startTimer(timeout)

	print("starting tree farm")
	local ev = {}

	while (true) do
		print(data.time)
		if (ev[1]=="timer") then
			if (ev[2]==counter) then
				data.time = data.time +1
				counter = os.startTimer(timeout)
			else
				-- CHECK IF WORK REQUEST WASN'T ACCEPTED
				for it,job in pairs(data.jobqueue) do
					if (job.exec~=true and job.timeout==ev[2]) then
						job.timeout=nil
						data.turtle[job.asked].notfree=false
						break
					end
				end
			end
		elseif (ev[1]=="modem_message") then
			local message = textutils.unserialize( ev[5] )
			if (message~=nil and message.request~=nil) then

				if (message.request=="ping") then -- regular update about turtle state
					print("PING MESSAGE")
					if (data.turtle[message.ID]~=nil) then
						data.turtle[message.ID].robot=message.robot;

						if (message.robot.state==1) then
							local robo=data.turtle[message.ID]
							if (robo~=nil and robo.notfree~=true and robo.robot~=nil and robo.robot.state==1) then  -- READY FOR JOB
								local minjob=nil
								print("robo ID ",robo.ID)
								for it, job in pairs(data.jobqueue) do
									job.cord=lain.taddCord(data.farm, job)

									if (job.exec~=true and job.timeout==nil and data.time>=job.time) then
										if (minjob==nil or lain.tdistance(robo.robot,job.cord)<lain.tdistance(minjob.cord,robo.robot)) then
											minjob=job
										end
									end
								end
								if (minjob~=nil) then -- SEND JOB REQUEST
									minjob.timeout=os.startTimer(jobtimeout)
									local response = {
										target = robo.ID,
										request = "job",
										job = minjob,
									}
									robo.notfree=true
									minjob.asked=robo.ID
									print("Sending job request to ",response.target)
									modem.transmit(robo.responseCh,basechannel,textutils.serialize(response))
								end
							end
						end
					end
				elseif (message.request=="startup") then
					print("STARTUP request")
					if (data.turtle[message.ID]==nil) then
						--NEED TO CALCULATE TURTLE HOME position
						data.turtle[message.ID]={}
						data.turtle[message.ID].homeLocal={
							x=data.tcnt,
							y=0,
							z=-1,
						}
						data.turtle[message.ID].ID = message.ID
						data.turtle[message.ID].robot = {}
						data.tcnt = data.tcnt + 1
						data.turtle[message.ID].home=lain.taddCord(data.farm, data.turtle[message.ID].homeLocal)
						data.turtle[message.ID].responseCh=ev[4]
					end
					data.turtle[message.ID].robot.x=message.robot.x
					data.turtle[message.ID].robot.y=message.robot.y
					data.turtle[message.ID].robot.z=message.robot.z
					data.turtle[message.ID].robot.f=message.robot.f
					data.turtle[message.ID].robot.state=message.robot.state

					local response = {
						target = message.ID,
						request = "startup",
						home = data.turtle[message.ID].home,
						saplingc = data.saplingc,
						fuelc = data.fuelc,
						woodc = data.woodc,
						torchc = data.torchc,
						dirtc = data.dirtc
					}
					modem.transmit(data.turtle[message.ID].responseCh,basechannel,textutils.serialize(response))

				elseif (message.request=="accepted") then  -- TURTLE IS GOING TO DO A JOB
					print("Job accept request")
					local accept_fail=true
					for it,job in pairs(data.jobqueue) do
						if (job.id == message.jobid and job.exec~=true) then
							data.turtle[message.ID].notfree=false
							job.exec=true
							job.timeout=nil
							local response = {
								target = message.ID,
								request = "accepted_response",
							}
							modem.transmit(data.turtle[message.ID].responseCh,basechannel,textutils.serialize(response))
							accept_fail = false
						end
					end

					if (accept_fail) then
						local response = {
							target = message.ID,
							request = "accepted_response_fail",
						}
						modem.transmit(data.turtle[message.ID].responseCh,basechannel,textutils.serialize(response))
					end

				elseif (message.request=="job_done") then  -- TURTLE FINISHED JOB
					print("job done request")

					local response = {
						target = message.ID,
						request = "job_done_response",
					}
					modem.transmit(data.turtle[message.ID].responseCh,basechannel,textutils.serialize(response))

					for it, job in pairs(data.jobqueue) do
						if (job.id==message.jobid) then
							data.turtle[message.ID].notfree=false
							if (job.jobt == jobType.Tree) then
								if (message.jobstatus == "DONE" ) then
									job.exec=false
									job.jobt=jobType.Sapling
									job.time=data.time
									job.timeout=nil
								elseif (message.jobstatus == "NOT GROWN") then
									job.exec=false
									job.time=data.time+(treeChopTime)
									job.timeout=nil
								end
							elseif (job.jobt == jobType.Torch) then
								if (message.jobstatus == "TORCH") then
									table.remove(data.jobqueue,it)
								end
							elseif (job.jobt == jobType.Dirt) then
								if (message.jobstatus == "DIRT") then
									job.exec=false
									job.time=data.time
									job.y= job.y + 1
									job.jobt = job.nextjob
									job.timeout=nil
								end
							elseif (job.jobt == jobType.Sapling) then
								if (message.jobstatus == "SAPLING") then
									job.exec = false
									job.time=data.time + treeChopTime
									job.jobt = jobType.Tree
									job.timeout=nil
								end
							end

							break
						end
					end

				end
			end
		end

		lain.writeData("base.log",data)
		ev = { os.pullEventRaw()}
	end
end

--[[
--
--
-- Start of main program
--
--
--
--]]
jobType={
	Dirt=5,
	Sapling=6,
	Torch=4,
	Tree=3
}

--monitor = peripheral.wrap(monitorSide)
--monitor.setTextScale(0.5)

modem = peripheral.wrap(modemSide)

--term.redirect(peripheral.wrap("top"))

term.clear()

ccontrol = lain.CoroutineControl:new()
--ccontrol:addCoroutine(lain.DisplayEvents, {monitor})
ccontrol:addCoroutine(TreeFarmControl, {term.current(), modem})

ccontrol:loop()

