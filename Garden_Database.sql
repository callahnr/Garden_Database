/*
	Garden Database Script
	2.09.2020
	@author : Nathan Callahan
	@author : Soumya Mitra
	@description: This database is a record keeper for gardeners. It stores all information for the care of each plant in a garden 
	from sowing to harvest. It maintains a record of the weather conditions and condtion of the plant throughout the lifetime of the plant.
		Tables:
			-Plant: Records individual plant information
			-PlantType: Records plant species information
			-Weather: Records weather conditions
			-Havest: Records the information from a harvest. (i.e. harvested amount, date of harvest, ect.)
			-ActionTbl: A table of actions taken while tending
			-LocationTbl: Records of the location. Allows for multiple beds or fields and unlimited columns and rows per field.
			-Photos: Records the file path of photos taken of plants and stores the height and width of the images.
			-Soil: Record of soil conditions.
			-Tended: Record of tending date and actions taken (i.e. fertilized, watered, ect.)
*/

USE master;
GO

DROP DATABASE IF EXISTS Garden;
GO

CREATE DATABASE Garden;
GO

USE Garden;
GO

--===================================================================
--======================== TABLES ===================================
--===================================================================


CREATE TABLE weatherTbl (
	weatherId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	humidity			INT				NOT NULL,
	temperature			INT				NOT NULL,
	precipitation		INT				NOT NULL,
	overcast			INT				NOT NULL,
	windSpeed			INT				NOT NULL,
	windDirection		CHAR(2)	 		NOT NULL	DEFAULT('N'),
	recordedDate		DATETIME		NOT NULL
);

CREATE TABLE plantTypeTbl (
	plantTypeId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	plantName			VARCHAR(40)		NOT NULL,
	plantBreed			VARCHAR(40)		NOT NULL,
	daysToHarvest		INT				NOT NULL	DEFAULT(0),
	[description]		VARCHAR(1000)	NOT NULL	DEFAULT(''),
	archived			BIT				NOT NULL	DEFAULT(0)
);


CREATE TABLE actionTbl (
	actionId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	planted				BIT				NOT NULL	DEFAULT(0),
	watered				BIT				NOT NULL	DEFAULT(0),
	fertilized			BIT				NOT NULL	DEFAULT(0),
	depested			BIT				NOT NULL	DEFAULT(0),
	noAction			BIT				NOT NULL	DEFAULT(0)
)

CREATE TABLE locationTbl (
	locationId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	fieldColumn			INT				NOT NULL,
	fieldRow			INT				NOT NULL,
	fieldName			VARCHAR(30)		NOT NULL
);

CREATE TABLE Photos (
	photoId				INT				NOT NULL	PRIMARY KEY		IDENTITY,
	photoPath			VARCHAR(60)		NOT NULL,
	width				INT				NOT NULL,
	height				INT				NOT NULL
)

CREATE TABLE soilConditionTbl (
	soilCondId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	recordedDate		DATETIME		NOT NULL,
	pH					FLOAT			NOT NULL,
	moistureLvl			FLOAT			NOT NULL,
	nitrogenLvl			FLOAT			NOT NULL,
	phosoLvl			FLOAT			NOT NULL
)

CREATE TABLE plantTbl	 (					
	plantId				INT				NOT NULL	PRIMARY KEY		IDENTITY,
	plantTypeId			INT				NOT NULL	FOREIGN KEY REFERENCES plantTypeTbl(plantTypeId),
	harvestId			INT,
	tendedId			INT,
	locationId			INT,
	photoId				INT,
	archived			INT				NOT NULL	DEFAULT(0)
)

CREATE TABLE harvestTbl (
	harvestId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	plantID				INT				NOT NULL	FOREIGN KEY REFERENCES plantTbl(plantId),
	recordedDate		DATETIME		NOT NULL,
	numHarvest			FLOAT			NOT NULL,
	numWaste			FLOAT			NOT NULL
)

CREATE TABLE tendedTbl (
	tendedId			INT				NOT NULL	PRIMARY KEY		IDENTITY,
	plantId				INT				NOT NULL	FOREIGN KEY REFERENCES plantTbl(plantId),
	actionId			INT				NOT NULL	FOREIGN KEY REFERENCES actionTbl(actionId),
	soilCondId			INT				NOT NULL	FOREIGN KEY REFERENCES soilConditionTbl(soilCondId),
	recordedDate		DATETIME		NOT NULL,
	plantCondition		VARCHAR(30)		NOT NULL
)

GO
/************************************************************************************************************  
												CREATE VIEWS
*************************************************************************************************************/
CREATE VIEW vwPlantList AS 
	SELECT p.plantId, pt.plantName, pt.plantBreed, pt.[description]
	FROM plantTbl p, plantTypeTbl pt 
	WHERE p.plantTypeId = pt.plantTypeId AND p.archived = 0
GO

CREATE VIEW vwTypeList AS
	SELECT pt.plantName, pt.plantBreed, pt.description
	FROM plantTypeTbl pt
GO

CREATE VIEW vwWateredList AS
	SELECT DISTINCT p.plantId, pt.plantName, pt.plantBreed, t.recordedDate, a.watered
	FROM	(plantTbl p	LEFT JOIN tendedTbl t ON p.plantId = t.plantId 
						LEFT JOIN actionTbl a ON t.actionId = a.actionId 
						LEFT JOIN plantTypeTbl pt ON pt.plantTypeId = p.plantTypeId
			)
	WHERE p.plantId = t.plantId AND a.watered = 1
GO

CREATE VIEW vwDepestedList AS
	SELECT DISTINCT p.plantId, pt.plantName, pt.plantBreed, t.recordedDate, a.depested
	FROM	(plantTbl p	LEFT JOIN tendedTbl t ON p.plantId = t.plantId 
						LEFT JOIN actionTbl a ON t.actionId = a.actionId 
						LEFT JOIN plantTypeTbl pt ON pt.plantTypeId = p.plantTypeId
			)
	WHERE p.plantId = t.plantId AND a.depested = 1
GO

CREATE VIEW vwFertilizedList AS
	SELECT DISTINCT p.plantId, pt.plantName, pt.plantBreed, t.recordedDate, a.fertilized
	FROM	(plantTbl p	LEFT JOIN tendedTbl t ON p.plantId = t.plantId 
						LEFT JOIN actionTbl a ON t.actionId = a.actionId 
						LEFT JOIN plantTypeTbl pt ON pt.plantTypeId = p.plantTypeId
			)
	WHERE p.plantId = t.plantId AND a.fertilized = 1
GO

CREATE VIEW vwPlantedList AS
	SELECT	p.plantId, pt.plantName, pt.plantBreed, t.recordedDate, a.planted
	FROM	(plantTbl p	LEFT JOIN tendedTbl t ON p.plantId = t.plantId 
						LEFT JOIN actionTbl a ON t.actionId = a.actionId 
						LEFT JOIN plantTypeTbl pt ON pt.plantTypeId = p.plantTypeId
			)
	WHERE p.plantId = t.plantId AND a.planted = 1
GO

CREATE VIEW vwHarvestDate AS
	SELECT p.plantId, pt.daysToHarvest, t.recordedDate AS [datePlanted], DATEADD(day, pt.daysToHarvest, t.recordedDate) AS [harvestDate]
	FROM plantTbl p LEFT JOIN plantTypeTbl pt ON p.plantTypeId = pt.plantTypeId, tendedTbl t 
					LEFT JOIN actionTbl a on t.actionId = a.actionId

	WHERE p.plantId = t.plantId
GO

CREATE VIEW vwPlantLocation AS
	SELECT p.plantId, l.fieldName, l.fieldColumn, l.fieldRow 
	FROM plantTbl p JOIN locationTbl l on p.locationId = l.locationId

GO
/************************************************************************************************************  
												STORED PROCEEDURES
*************************************************************************************************************/
/* =====================================================================

	Name:           spAddUpdateArchivePlant
	Purpose:        Adds/Updates/Archives a plant to/from the database

======================================================================== */
GO

CREATE PROCEDURE spAddUpdateArchivePlant
	@plantId		INT,
	@plantTypeId	INT,
	@harvestId		INT,
	@tendedId		INT,
	@locationId		INT,
	@archived		INT
		
AS BEGIN
BEGIN TRY
	IF(@plantId = 0) BEGIN   
		IF EXISTS(SELECT TOP(1) NULL FROM plantTbl WHERE plantId = @plantId)  BEGIN
			SELECT -1 AS plantId
			SELECT	[message] = 'PlantType ID already exsists',
					[success] = CAST(0 AS BIT)
		END
		ELSE BEGIN
			INSERT INTO plantTbl	(plantTypeId, harvestId, tendedId, locationId) VALUES 
								(@plantTypeId, @harvestId, @tendedId, @locationId)	

			SELECT @@IDENTITY AS plantId
		END
	END 

	ELSE IF(@archived = 1) BEGIN  -- ARCHIVE PLANT PROFILE

		IF NOT EXISTS (SELECT NULL FROM plantTbl WHERE plantId = @plantId) BEGIN
			SELECT -1 AS plantId
			SELECT	[message] = 'Plant ID does NOT exsist',
					[success] = CAST(0 AS BIT)
		END ELSE

		IF	EXISTS (SELECT TOP(1) NULL FROM tendedTbl 
			WHERE plantId = @plantId) BEGIN
				UPDATE	Plants 
				SET		archived = 1 
				WHERE	plantId = @plantId 
				SELECT @plantId AS plantId
					SELECT	[message] = 'Plant ID archived',
					[success] = CAST(1 AS BIT)
		END

		ELSE BEGIN
			DELETE FROM plantTbl WHERE plantId = @plantId
			SELECT	[message] = 'Plant ID hard deleted',
					[success] = CAST(1 AS BIT)
		END
	END
END TRY BEGIN CATCH
	
	IF(@@TRANCOUNT > 0) ROLLBACK TRAN

END CATCH

	IF(@@TRANCOUNT > 0) COMMIT TRAN

END



/* =====================================================================

	Name:           spAddUpdateArchivePlantType
	Purpose:        Adds/Updates/Archives a plant type to/from the database

======================================================================== */
GO

	CREATE PROCEDURE spAddUpdateArchivePlantType
		@plantTypeId			INT,
		@plantName				VARCHAR(40),
		@plantBreed				VARCHAR(40),
		@daysToHarvest			INT,
		@description			VARCHAR(100),
		@archived				INT
AS BEGIN
BEGIN TRY
	IF(@plantTypeId = 0) 
		BEGIN   
			IF EXISTS(SELECT TOP(1) NULL FROM plantTbl
			WHERE plantTypeId = @plantTypeId)  
			BEGIN
				SELECT -1 AS plantTypeId
			SELECT	[message] = 'PlantType ID already exists',
					[success] = CAST(0 AS BIT)
			END
		ELSE 
			BEGIN
				INSERT INTO plantTypeTbl (
					plantTypeId,	
					plantName,
					plantBreed,	
					daysToHarvest,
					[description]	
				)
				VALUES (
					@plantTypeId,
					@plantName,
					@plantBreed,
					@daysToHarvest,
					@description
				)
				SELECT @@IDENTITY AS plantTypeId
			END
		END

	ELSE IF(@archived = 1) 
	BEGIN

		IF NOT EXISTS (SELECT NULL FROM plantTypeTbl WHERE plantTypeId = @plantTypeId) 
		BEGIN
			SELECT -1 AS plantTypeId
			SELECT	[message] = 'PlantType ID does not exists',
					[success] = CAST(0 AS BIT)
		END 
		ELSE

		IF	EXISTS (SELECT TOP(1) NULL FROM plantTbl 
			WHERE plantTypeId = @plantTypeId)
		BEGIN
				UPDATE	plantTypeTbl 
				SET		archived = 1 
				WHERE	plantTypeId = @plantTypeId 
				SELECT @plantTypeId AS plantTypeId
			SELECT	[message] = 'PlantType ID does archived',
					[success] = CAST(1 AS BIT)
		END

		ELSE BEGIN
			DELETE FROM plantTypeId WHERE plantTypeId = @plantTypeId
						SELECT	[message] = 'PlantType ID hard deleted',
								[success] = CAST(1 AS BIT)
		END
	END
END TRY BEGIN CATCH
	
	IF(@@TRANCOUNT > 0) ROLLBACK TRAN

END CATCH

	IF(@@TRANCOUNT > 0) COMMIT TRAN

END

/* =====================================================================

	Name:           spAddUpdateDelete_Weather
	Purpose:        Adds/Updates/Deletes weather entries to/from the database

======================================================================== */
Go
CREATE PROCEDURE spAddUpdateArchive_Weather
	@weatherId			INT,	
	@humidity			INT,	
	@temperature		INT,			
	@precipitation		INT,	
	@overcast			INT,	
	@windSpeed			INT,	
	@windDirection		CHAR,	 
	@recordedDate		DATETIME,
	@archive			BIT = 0
AS BEGIN
	
BEGIN TRY
	IF(@weatherId = 0) BEGIN			-- ADD weather
		IF EXISTS (SELECT TOP(1) NULL FROM weatherTbl WHERE weatherId = @weatherId) BEGIN
			SELECT	[message] = 'Weather ID already exists',
					[success] = CAST(0 AS BIT)
		END ELSE BEGIN

		INSERT INTO weatherTbl	(humidity, temperature, precipitation, overcast, windSpeed, windDirection, recordedDate) VALUES
							(@humidity, @temperature, @precipitation, @overcast, @windSpeed, @windDirection, @recordedDate)
		SELECT	@@IDENTITY AS weatherId,
				[success] = CAST(1 AS BIT)
		END

	END ELSE IF(@archive = 1) BEGIN		-- DELETE weather
		IF NOT EXISTS (SELECT TOP(1) NULL FROM weatherTbl WHERE weatherId = @weatherId) BEGIN
			SELECT	[message] = 'Weather ID does not exist',
					[success] = CAST(0 AS BIT)
		END ELSE BEGIN

			DELETE FROM weatherTbl WHERE weatherId = @weatherId
			SELECT	0 as weatherId, 
					[success] = CAST(1 AS BIT)
		END

	END ELSE BEGIN						-- UPDATE weather
		IF NOT EXISTS (SELECT TOP(1) NULL FROM weatherTbl WHERE weatherId = @weatherId) BEGIN
			SELECT	[message] = 'Weather ID does not exist',
					[success] = CAST(0 AS BIT)
		END ELSE BEGIN
			
			UPDATE weatherTbl
			SET humidity = @humidity, temperature = @temperature, precipitation = @precipitation, 
				overcast = @overcast, windSpeed = @windSpeed, windDirection = @windDirection, recordedDate = @recordedDate
			WHERE weatherId = @weatherId

			SELECT	@weatherId as weatherId, 
					[success] = CAST(1 AS BIT)
		END

	END
END TRY BEGIN CATCH
	
	IF(@@TRANCOUNT > 0) ROLLBACK TRAN

END CATCH

	IF(@@TRANCOUNT > 0) COMMIT TRAN

END


/* =====================================================================

	Name:           spGetPlantBreedByName
	Purpose:        Gets a list of all plants from the database by name.

======================================================================== */
GO
CREATE PROCEDURE spGetPlantBreedByName
	@plantBreedName		VARCHAR(64),
	@hardMatch			BIT = 0
AS BEGIN
	IF (@hardMatch = 1) BEGIN
		SELECT *
		FROM vwTypeList tl
		WHERE tl.plantBreed = @plantBreedName
	END ELSE BEGIN
		SELECT *
		FROM vwTypeList tl
		WHERE tl.plantBreed LIKE CONCAT('%', @plantBreedName, '%')
	END
END
GO

/* =====================================================================

	Name:           spGetPlantByTypeName
	Purpose:        Gets a list of all plants from the database by name.

======================================================================== */
GO
CREATE PROCEDURE spGetPlantByTypeName
	@plantType				VARCHAR(64),
	@hardMatch				BIT = 0
AS BEGIN
	IF (@hardMatch = 1) BEGIN
		SELECT *
		FROM vwTypeList tl
		WHERE tl.plantName = @plantType
	END ELSE BEGIN
		SELECT *
		FROM vwTypeList tl
		WHERE tl.plantName LIKE CONCAT('%', @plantType, '%')
	END
END
GO

/* =====================================================================

	Name:           spGetWeatherByDate
	Purpose:        Get all weather data between a date range

======================================================================== */
GO
CREATE PROCEDURE spGetWeatherByDate
	@startDate				DATETIME,
	@endDate				DATETIME
AS BEGIN
		SELECT *
		FROM weatherTbl	w
		WHERE w.recordedDate BETWEEN @startDate AND @endDate
END
GO


SELECT * FROM weatherTbl
/* =====================================================================

	Name:           spGetPlantConditionByDate
	Purpose:        Get all plant conditions between a date range

======================================================================== */
GO
CREATE PROCEDURE spGetPlantConditionByDate
	@startDate				DATETIME,
	@endDate				DATETIME
AS BEGIN
		SELECT t.plantId, t.recordedDate, t.plantCondition
		FROM tendedTbl t
		WHERE t.recordedDate BETWEEN @startDate AND @endDate
END
GO


/* =====================================================================

	Name:           spGetLocByPlantType
	Purpose:        Get all weather data between a date range

======================================================================== */
GO
CREATE PROCEDURE spGetLocByPlantType
		@plantType		VARCHAR(64)
AS BEGIN
		SELECT DISTINCT pl.*, pt.plantName
		FROM vwPlantLocation pl LEFT JOIN plantTbl p ON pl.plantId = p.plantTypeId, plantTypeTbl pt
		WHERE pt.plantName LIKE CONCAT('%', 'Tomato', '%')
END
GO


/* =====================================================================

	Name:           spGetLocByPlantType
	Purpose:        Get all weather data between a date range

======================================================================== */
GO
CREATE PROCEDURE spGetSoilListByPh(
		@startRange		FLOAT,
		@endRange		FLOAT
		)
AS BEGIN

		SELECT sc.*
		FROM soilConditionTbl sc
		WHERE sc.pH BETWEEN @startRange AND @endRange
END
GO
/* =====================================================================

	Name:           spGetHarvestsByDateRange
	Purpose:        Get all weather data between a date range

======================================================================== */
GO
CREATE PROCEDURE spGetHarvestsByDateRange
	@startDate				DATETIME,
	@endDate				DATETIME
AS BEGIN

		SELECT hd.plantId, hd.harvestDate
		FROM vwHarvestDate hd
		WHERE hd.harvestDate BETWEEN @startDate AND @endDate
		GROUP BY hd.plantId, hd.harvestDate
END
GO



--spErrorRecord --Record database errors
/************************************************************************************************************  
												INSERT DATA
*************************************************************************************************************/
SET IDENTITY_INSERT weatherTbl ON
INSERT INTO weatherTbl (weatherId, humidity, temperature, precipitation, overcast, windSpeed, windDirection, recordedDate) VALUES (1, 37, 39, 63, 35, 25, 'SE', '12/31/2019'),
(2, 68, 81, 46, 79, 62, 'N', '3/27/2020'),
(3, 9, 34, 62, 68, 57, 'NE', '1/22/2020'),
(4, 85, 123, 95, 70, 35, 'E', '6/4/2019'),
(5, 64, 67, 12, 65, 63, 'W', '5/15/2019'),
(6, 60, 68, 64, 5, 8, 'N', '4/15/2020'),
(7, 88, 104, 98, 26, 37, 'W', '7/7/2019'),
(8, 82, 100, 89, 3, 63, 'W', '2/20/2020'),
(9, 67, 12, 50, 21, 60, 'NW', '10/4/2019'),
(10, 20, 37, 50, 78, 4, 'NE', '10/21/2019'),
(11, 24, 90, 49, 72, 53, 'NW', '9/23/2019'),
(12, 57, 121, 85, 95, 23, 'N', '4/17/2020'),
(13, 6, 89, 37, 36, 17, 'NE', '10/13/2019'),
(14, 53, 45, 68, 13, 62, 'NW', '7/31/2019'),
(15, 61, 115, 54, 28, 3, 'E', '11/21/2019'),
(16, 26, 125, 90, 46, 48, 'N', '3/27/2020'),
(17, 45, 37, 14, 80, 5, 'S', '8/13/2019'),
(18, 47, 39, 28, 24, 26, 'N', '7/24/2019'),
(19, 46, 64, 13, 87, 49, 'W', '9/5/2019'),
(20, 90, 42, 79, 57, 53, 'E', '11/25/2019'),
(21, 19, 15, 74, 45, 25, 'SE', '1/10/2020'),
(22, 22, 45, 91, 32, 53, 'N', '5/11/2019'),
(23, 82, 79, 81, 91, 16, 'E', '3/8/2020'),
(24, 54, 29, 48, 25, 60, 'NW', '7/15/2019'),
(25, 60, 53, 42, 15, 36, 'SW', '12/13/2019'),
(26, 48, 98, 36, 9, 44, 'N', '1/9/2020'),
(27, 94, 13, 16, 98, 5, 'NE', '1/21/2020'),
(28, 55, 35, 29, 90, 63, 'N', '9/26/2019'),
(29, 13, 72, 79, 17, 40, 'N', '8/5/2019'),
(30, 100, 40, 22, 28, 50, 'SW', '6/11/2019'),
(31, 25, 22, 67, 81, 13, 'SE', '4/7/2020'),
(32, 57, 25, 26, 71, 61, 'NE', '7/29/2019'),
(33, 30, 46, 61, 14, 7, 'SW', '10/31/2019'),
(34, 10, 108, 72, 6, 59, 'W', '5/15/2019'),
(35, 85, 97, 67, 22, 41, 'NW', '10/25/2019'),
(36, 52, 18, 30, 11, 53, 'NW', '7/21/2019'),
(37, 56, 13, 45, 91, 23, 'NW', '1/17/2020'),
(38, 29, 79, 73, 5, 18, 'S', '11/4/2019'),
(39, 22, 56, 72, 50, 6, 'W', '1/15/2020'),
(40, 17, 96, 89, 74, 45, 'N', '10/9/2019'),
(41, 30, 108, 41, 66, 21, 'W', '10/27/2019'),
(42, 16, 101, 93, 4, 30, 'S', '4/20/2020'),
(43, 46, 23, 27, 58, 58, 'SE', '8/23/2019'),
(44, 84, 71, 55, 67, 58, 'NE', '5/13/2019'),
(45, 13, 77, 56, 27, 8, 'NW', '10/1/2019'),
(46, 49, 82, 30, 22, 71, 'N', '5/10/2019'),
(47, 27, 35, 97, 33, 8, 'E', '1/30/2020'),
(48, 23, 106, 56, 53, 26, 'NE', '3/2/2020'),
(49, 10, 89, 95, 79, 66, 'N', '7/4/2019'),
(50, 85, 94, 78, 86, 7, 'W', '9/8/2019'),
(51, 82, 16, 71, 35, 19, 'E', '1/19/2020'),
(52, 54, 7, 3, 49, 69, 'E', '9/17/2019'),
(53, 60, 33, 90, 1, 72, 'W', '1/17/2020'),
(54, 74, 23, 11, 31, 46, 'E', '12/1/2019'),
(55, 36, 22, 32, 76, 38, 'W', '12/8/2019'),
(56, 53, 105, 97, 12, 12, 'NE', '12/28/2019'),
(57, 36, 88, 44, 65, 18, 'N', '5/21/2019'),
(58, 10, 10, 21, 29, 1, 'N', '3/2/2020'),
(59, 58, 91, 81, 63, 50, 'N', '8/16/2019'),
(60, 17, 22, 33, 87, 15, 'E', '3/14/2020'),
(61, 46, 75, 65, 57, 26, 'W', '1/31/2020'),
(62, 4, 18, 53, 28, 61, 'W', '5/22/2019'),
(63, 48, 27, 48, 30, 57, 'E', '5/20/2019'),
(64, 52, 84, 70, 87, 57, 'W', '10/21/2019'),
(65, 81, 44, 49, 57, 39, 'NW', '5/6/2020'),
(66, 34, 125, 69, 67, 21, 'SW', '8/28/2019'),
(67, 44, 38, 35, 99, 5, 'NW', '10/27/2019'),
(68, 38, 23, 9, 24, 30, 'E', '4/1/2020'),
(69, 97, 92, 95, 84, 24, 'E', '3/1/2020'),
(70, 78, 111, 44, 75, 9, 'SE', '7/2/2019'),
(71, 84, 70, 89, 14, 26, 'SE', '3/1/2020'),
(72, 98, 27, 1, 68, 54, 'S', '10/11/2019'),
(73, 21, 105, 90, 13, 35, 'NW', '4/4/2020'),
(74, 31, 116, 54, 30, 24, 'E', '10/8/2019'),
(75, 76, 110, 77, 43, 21, 'NW', '5/10/2019'),
(76, 76, 107, 90, 26, 18, 'SE', '6/20/2019'),
(77, 67, 66, 79, 63, 54, 'NW', '2/17/2020'),
(78, 87, 93, 1, 86, 35, 'SW', '3/3/2020'),
(79, 85, 90, 12, 51, 59, 'E', '6/16/2019'),
(80, 60, 106, 13, 58, 13, 'E', '8/20/2019'),
(81, 99, 94, 34, 73, 70, 'SE', '9/13/2019'),
(82, 49, 54, 44, 45, 68, 'NW', '11/17/2019'),
(83, 88, 18, 38, 81, 63, 'SW', '5/4/2020'),
(84, 51, 88, 68, 99, 75, 'NW', '3/11/2020'),
(85, 10, 16, 84, 58, 54, 'N', '8/6/2019'),
(86, 88, 3, 94, 35, 51, 'NW', '1/26/2020'),
(87, 86, 89, 18, 49, 16, 'NE', '6/12/2019'),
(88, 89, 42, 91, 0, 54, 'NW', '4/19/2020'),
(89, 24, 94, 44, 100, 64, 'SE', '6/22/2019'),
(90, 2, 71, 28, 6, 73, 'NW', '4/24/2020'),
(91, 84, 17, 44, 76, 2, 'S', '2/10/2020'),
(92, 10, 23, 2, 31, 35, 'SE', '2/13/2020'),
(93, 25, 36, 68, 98, 41, 'NE', '9/7/2019'),
(94, 58, 4, 16, 96, 62, 'E', '6/18/2019'),
(95, 77, 37, 12, 100, 46, 'N', '8/11/2019'),
(96, 42, 26, 1, 60, 41, 'NW', '7/23/2019'),
(97, 88, 92, 52, 31, 37, 'S', '12/31/2019'),
(98, 13, 109, 21, 33, 49, 'NW', '11/6/2019'),
(99, 60, 108, 67, 100, 74, 'S', '6/13/2019'),
(100, 8, 48, 71, 92, 49, 'S', '2/16/2020'),
(101, 52, 15, 70, 14, 19, 'NW', '4/30/2020'),
(102, 70, 42, 46, 67, 14, 'NE', '8/21/2019'),
(103, 43, 24, 43, 51, 34, 'SW', '6/14/2019'),
(104, 80, 122, 52, 71, 33, 'N', '10/8/2019'),
(105, 75, 76, 97, 86, 4, 'W', '12/1/2019'),
(106, 6, 70, 45, 2, 18, 'SW', '6/9/2019'),
(107, 62, 11, 75, 66, 51, 'NE', '8/19/2019'),
(108, 93, 59, 21, 37, 13, 'NE', '3/10/2020'),
(109, 89, 59, 43, 4, 37, 'SE', '12/11/2019'),
(110, 20, 53, 78, 2, 43, 'SE', '1/1/2020'),
(111, 59, 77, 27, 86, 3, 'NE', '5/5/2020'),
(112, 11, 18, 21, 75, 10, 'N', '9/17/2019'),
(113, 69, 70, 32, 3, 5, 'E', '12/11/2019'),
(114, 1, 46, 80, 32, 2, 'E', '2/17/2020'),
(115, 8, 93, 66, 18, 14, 'SE', '11/22/2019'),
(116, 66, 13, 51, 18, 65, 'S', '11/13/2019'),
(117, 20, 116, 99, 19, 14, 'NW', '7/3/2019'),
(118, 93, 121, 74, 84, 19, 'S', '11/3/2019'),
(119, 64, 97, 41, 8, 29, 'NE', '8/3/2019'),
(120, 81, 69, 63, 83, 72, 'NE', '8/5/2019'),
(121, 5, 117, 31, 66, 72, 'NE', '5/23/2019'),
(122, 86, 60, 11, 52, 41, 'E', '10/12/2019'),
(123, 56, 30, 77, 50, 22, 'N', '10/3/2019'),
(124, 86, 6, 67, 88, 51, 'SE', '12/16/2019'),
(125, 44, 5, 13, 9, 59, 'SW', '9/6/2019'),
(126, 88, 118, 9, 13, 68, 'N', '9/25/2019'),
(127, 57, 61, 74, 39, 18, 'W', '9/16/2019'),
(128, 35, 124, 14, 71, 62, 'NW', '8/1/2019'),
(129, 11, 63, 11, 64, 61, 'W', '1/8/2020'),
(130, 5, 117, 58, 68, 61, 'W', '6/15/2019'),
(131, 88, 5, 23, 5, 70, 'SW', '5/19/2019'),
(132, 91, 93, 8, 51, 8, 'W', '6/5/2019'),
(133, 100, 17, 18, 27, 34, 'S', '8/22/2019'),
(134, 45, 14, 80, 37, 22, 'NE', '5/27/2019'),
(135, 2, 21, 55, 64, 26, 'SW', '10/2/2019'),
(136, 3, 91, 5, 68, 51, 'SW', '12/13/2019'),
(137, 75, 67, 37, 30, 50, 'NE', '9/5/2019'),
(138, 21, 24, 82, 52, 12, 'W', '2/7/2020'),
(139, 69, 52, 9, 73, 20, 'SE', '9/3/2019'),
(140, 72, 23, 68, 51, 11, 'N', '1/16/2020'),
(141, 7, 7, 72, 39, 12, 'NW', '12/12/2019'),
(142, 2, 25, 72, 7, 5, 'E', '3/5/2020'),
(143, 48, 77, 39, 97, 3, 'SW', '2/20/2020'),
(144, 81, 92, 8, 26, 47, 'E', '11/3/2019'),
(145, 58, 13, 13, 50, 69, 'NW', '2/29/2020'),
(146, 43, 58, 7, 99, 57, 'SE', '2/26/2020'),
(147, 8, 34, 15, 10, 46, 'S', '3/27/2020'),
(148, 28, 113, 12, 55, 35, 'E', '4/5/2020'),
(149, 50, 39, 100, 54, 51, 'NE', '6/29/2019'),
(150, 93, 63, 96, 34, 49, 'NE', '5/2/2020'),
(151, 2, 52, 56, 17, 22, 'SE', '4/9/2020'),
(152, 17, 108, 81, 92, 66, 'W', '7/31/2019')
SET IDENTITY_INSERT weatherTbl OFF

SET IDENTITY_INSERT soilConditionTbl ON
INSERT INTO soilConditionTbl (soilCondId, recordedDate, pH, moistureLvl, nitrogenLvl, phosoLvl) 
VALUES 
(1,   '11/21/2019', -3.6, 0.98, 0.52, 0.24),
(2,   '2/8/2020',    5.9, 0.22, 0.99, 0.53),
(3,   '10/1/2019',   0.2, 0.47, 0.12, 0.39),
(4,   '6/10/2019',   5.6, 0.67, 0.55, 0.01),
(5,   '2/20/2020',   3.9, 0.8, 0.9, 0.26),
(6,   '4/21/2020',   2.6, 0.57, 0.89, 0.99),
(7,   '4/16/2020',  -3.4, 0.12, 0.73, 0.99),
(8,   '10/13/2019',  3.4, 0.75, 0.49, 0.01),
(9,   '9/16/2019',  -5.1, 0.46, 0.91, 0.23),
(10,  '10/17/2019', -2.1, 0.13, 0.92, 0.79),
(11,  '4/28/2020',  -6.2, 0.41, 0.08, 0.42),
(12,  '11/20/2019', -3.8, 0.23, 0.31, 0.53),
(13,  '12/16/2019',  1.0, 0.64, 0.65, 0.5),
(14,  '4/9/2020',   -4.1, 0.99, 0.36, 0.05),
(15,  '1/16/2020',   4.1,  0.63, 0.15, 0.67),
(16,  '6/7/2019',    1.0,  0.88, 0.22, 0.02),
(17,  '7/25/2019',   4.1, 0.59, 0.9, 0.31),
(18,  '7/25/2019',   1.9,  0.97, 0.94, 0.59),
(19,  '9/2/2019',    1.7,  0.87, 0.51, 0.86),
(20,  '7/18/2019',  -3.4, 0.52, 0.2, 0.45),
(21,  '7/30/2019',  -4.8, 0.64, 0.84, 0.7),
(22,  '2/27/2020',  -5.7,0.28, 0.83, 0.26),
(23,  '4/24/2020',  -3.4, 0.3, 0.67, 0.3),
(24,  '1/14/2020',  -1.7, 0.11, 0.64, 0.32),
(25,  '7/4/2019',    0.3,  0.71, 0.51, 0.13),
(26,  '5/17/2019',  -3.2, 0.68, 0.95, 0.82),
(27,  '12/24/2019',  2.5, 0.4, 0.38, 0.02),
(28,  '4/5/2020',    0.6,  0.51, 0.01, 0.45),
(29,  '12/18/2019',  0.2,  1.0, 0.3, 0.89),
(30,  '8/24/2019',  -2.2, 0.23, 0.88, 0.52),
(31,  '6/12/2019',  -0.2, 0.27, 0.03, 0.32),
(32,  '4/28/2020',  -6.2, 0.82, 0.6, 0.03),
(33,  '8/16/2019',  -2.7, 0.97, 0.31, 0.05),
(34,  '1/31/2020',  -4.1, 0.52, 0.33, 0.0),
(35,  '5/1/2020',    3.8,  0.35, 0.41, 0.88),
(36,  '3/20/2020',  -4.1, 0.25, 0.88, 0.93),
(37,  '3/18/2020',   2.6,  0.26, 0.53, 0.21),
(38,  '9/30/2019',  -3.5, 0.59, 0.18, 0.04),
(39,  '4/6/2020',    5.0,  0.09, 0.28, 0.58),
(40,  '9/23/2019',   1.3,  0.68, 0.63, 0.21),
(41,  '6/26/2019',   2.7,  0.48, 0.24, 0.2),
(42,  '10/17/2019',  3.1,  0.31, 0.7, 1.0),
(43,  '12/12/2019',  3.2, 0.26, 0.05, 0.4),
(44,  '5/31/2019',  -0.4, 0.26, 0.25, 0.87),
(45,  '8/14/2019',  -2.0, 0.35, 0.22, 0.04),
(46,  '10/19/2019', -0.4, 0.05, 0.26, 0.58),
(47,  '9/22/2019',  -0.1, 0.6, 0.89, 0.74),
(48,  '10/29/2019',  4.5,  0.8, 0.64, 0.69),
(49,  '10/20/2019',  6.3,  0.44, 0.18, 0.12),
(50,  '1/13/2020',  -6.2, 0.75, 0.88, 0.71),
(51,  '9/28/2019',  -1.9, 0.61, 0.68, 0.47),
(52,  '11/17/2019',  0.7,  0.55, 0.61, 0.89),
(53,  '5/29/2019',  -1.2,  0.2, 0.74, 0.98),
(54,  '6/17/2019',  -6.4, 0.21, 0.31, 0.8),
(55,  '9/2/2019',    1.5,  0.53, 0.46, 0.92),
(56,  '10/13/2019',  6.4, 0.75, 0.57, 0.67),
(57,  '7/26/2019',   4.0,  0.83, 0.11, 0.81),
(58,  '7/26/2019',   4.2,  0.41, 0.76, 0.03),
(59,  '5/9/2019',   -3.7, 0.06, 0.16, 0.23),
(60,  '2/12/2020',  -6.8, 0.13, 0.47, 0.13),
(61,  '5/15/2019',  -0.7, 0.88, 0.27, 0.51),
(62,  '12/9/2019',  -4.0, 0.17, 0.03, 0.52),
(63,  '8/28/2019',  -6.4, 0.15, 0.29, 0.73),
(64,  '4/13/2020',   0.7,  0.65, 0.1, 0.15),
(65,  '2/25/2020',  -5.0, 0.46, 0.84, 0.69),
(66,  '6/1/2019',    0.3,  0.4, 0.43, 0.07),
(67,  '7/16/2019',   6.3, 0.22, 0.29, 0.67),
(68,  '12/13/2019', -6.3, 0.4, 0.03, 0.43),
(69,  '11/15/2019',  1.2,  0.23, 0.99, 0.77),
(70,  '6/13/2019',   6.8,  0.7, 0.67, 0.42),
(71,  '3/23/2020',   3.2,  0.06, 0.23, 0.01),
(72,  '10/31/2019',  4.3,  0.84, 0.58, 0.73),
(73,  '11/27/2019', -1.2, 0.33, 0.33, 0.4),
(74,  '10/18/2019',  3.3,  0.04, 0.39, 0.75),
(75,  '5/21/2019',   4.4,  0.65, 0.32, 0.08),
(76,  '1/31/2020',   5.6,  0.04, 0.48, 0.0),
(77,  '7/27/2019',  -4.1, 0.4, 0.9, 0.78),
(78,  '12/21/2019', -3.6, 0.89, 0.53, 0.75),
(79,  '6/20/2019',  -0.5, 0.97, 0.76, 0.59),
(80,  '6/16/2019',  -6.1, 0.88, 0.07, 0.98),
(81,  '3/7/2020',   -6.1, 0.17, 0.97, 1.0),
(82,  '5/4/2020',   -2.1, 0.21, 0.35, 0.41),
(83,  '1/31/2020',   1.1, 0.72, 0.83, 0.88),
(84,  '12/17/2019', -2.0, 0.73, 0.87, 0.7),
(85,  '12/10/2019',  4.8,  0.23, 0.97, 0.68),
(86,  '12/6/2019',  -5.4, 0.42, 0.98, 0.92),
(87,  '10/13/2019', -2.9, 0.53, 0.53, 0.32),
(88,  '4/28/2020',   4.0,   0.98, 0.22, 0.15),
(89,  '12/12/2019',  2.1,  0.38, 0.97, 0.23),
(90,  '6/19/2019',  -4.0, 0.03, 1.0, 0.29),
(91,  '2/14/2020',   1.1,  0.89, 0.17, 0.76),
(92,  '10/14/2019',  0.6,  0.88, 0.13, 0.4),
(93,  '3/22/2020',  -6.9, 0.09, 0.44, 0.71),
(94,  '3/5/2020',    3.6,  0.48, 0.25, 0.79),
(95,  '10/2/2019',  -3.5, 0.28, 0.18, 0.66),
(96,  '7/16/2019',   4.0,  0.34, 0.07, 0.33),
(97,  '5/19/2019',   4.7,  0.85, 0.85, 0.6),
(98,  '6/12/2019',   3.2,  0.44, 0.34, 0.87),
(99,  '1/26/2020',  -2.5, 0.92, 0.64, 0.46),
(100, '2/1/2020',   -5.1, 0.98, 0.66, 0.56),
(101, '11/7/2019',   4.8,  0.33, 0.89, 0.89),
(102, '10/30/2019', -3.2, 0.75, 0.18, 0.98),
(103, '7/23/2019',   1.5,  0.81, 0.9, 0.07),
(104, '4/28/2020',  -0.8, 0.59, 0.25, 0.9),
(105, '1/12/2020',   0.8, 0.74, 0.57, 0.2),
(106, '3/8/2020',    0.0,  0.12, 0.38, 0.95),
(107, '1/3/2020',    5.5, 0.48, 0.96, 0.15),
(108, '5/11/2019',  -4.8, 0.17, 0.66, 0.86),
(109, '12/12/2019', -0.4, 0.97, 0.97, 0.8),
(110, '7/15/2019',  -6.2, 0.38, 0.27, 0.94),
(111, '10/2/2019',  -5.0, 0.55, 0.17, 0.65),
(112, '8/27/2019',  -3.9, 0.11, 0.97, 0.29),
(113, '7/22/2019',  -4.0, 0.37, 0.68, 0.7),
(114, '1/19/2020',  -0.3, 0.8, 0.68, 0.34),
(115, '4/17/2020',  -2.6, 0.18, 0.3, 0.16),
(116, '12/16/2019', -6.6, 0.14, 0.79, 0.78),
(117, '8/2/2019',    0.5,  0.5, 0.36, 0.06),
(118, '5/23/2019',  -3.1, 0.68, 0.12, 0.28),
(119, '12/1/2019',  -6.5, 0.61, 0.99, 0.32),
(120, '6/7/2019',   -6.8, 0.03, 0.99, 0.38),
(121, '3/16/2020',   4.0,  0.39, 0.64, 0.95),
(122, '5/1/2020',   -5.3, 0.42, 0.8, 0.14),
(123, '7/15/2019',  -3.6, 0.32, 0.8, 0.25),
(124, '4/14/2020',   2.8,  0.72, 0.63, 0.65),
(125, '12/19/2019',  4.6,  0.39, 0.9, 0.28),
(126, '6/2/2019',   -1.2, 0.57, 0.28, 0.46),
(127, '6/13/2019',   4.5,  0.79, 0.92, 0.75),
(128, '1/21/2020',   6.1,  0.67, 0.83, 0.5),
(129, '4/6/2020',   -3.8, 0.24, 0.07, 0.53),
(130, '12/24/2019',  0.2,  1.0, 0.69, 0.23),
(131, '2/4/2020',   -3.2, 0.29, 0.55, 0.71),
(132, '12/18/2019', -0.8, 0.82, 0.48, 0.9),
(133, '8/23/2019',  -1.9, 0.64, 0.6, 0.36),
(134, '8/19/2019',   2.8,  0.76, 0.12, 0.88),
(135, '4/5/2020',    0.4,  0.24, 0.65, 0.57),
(136, '10/11/2019',  3.8,  0.38, 0.35, 0.85),
(137, '6/14/2019',  -6.6, 0.12, 0.14, 0.66),
(138, '9/15/2019',   1.7, 0.4, 0.59, 0.61),
(139, '9/20/2019',  -5.9, 0.59, 0.06, 0.7),
(140, '3/26/2020',  -1.6, 0.97, 0.39, 0.92),
(141, '3/1/2020',    0.2, 0.01, 0.34, 0.38),
(142, '3/18/2020',  -2.6, 0.02, 0.17, 0.94),
(143, '10/9/2019',  -4.6, 0.84, 0.11, 0.05),
(144, '5/23/2019',  -0.7, 0.62, 0.64, 0.57),
(145, '6/23/2019',  6.8,  0.84, 0.66, 0.34),
(146, '5/11/2019',  -5.1, 0.55, 0.59, 0.84),
(147, '10/12/2019', 3.5,  0.91, 0.38, 0.35),
(148, '4/27/2020',  -1.8, 0.55, 0.13, 0.19),
(149, '8/20/2019',  -5.6, 0.62, 0.04, 0.36),
(150, '7/16/2019',  3.3,  0.98, 0.9, 0.3),
(151, '5/6/2020',   2.9,  0.75, 0.96, 0.32),
(152, '12/16/2019', 3.5,  0.67, 0.84, 0.24)
SET IDENTITY_INSERT soilConditionTbl OFF
SELECT * FROM soilConditionTbl

SET IDENTITY_INSERT locationTbl ON
INSERT INTO locationTbl  (locationId, fieldName, fieldColumn, fieldRow) VALUES (1, 'NORTH',   1, 1),
(2, 'NORTH',   1, 2),
(3, 'NORTH',   1, 3),
(4, 'NORTH',   1, 4),
(5, 'NORTH',   1, 5),
(6, 'NORTH',   1, 6),
(7, 'NORTH',   1, 7),
(8, 'NORTH',   1, 8),
(9, 'NORTH',   1, 9),
(10, 'NORTH',  1, 10),
(11, 'NORTH',  1, 11),
(12, 'NORTH',  1, 12),
(13, 'NORTH',  1, 13),
(14, 'NORTH',  1, 14),
(15, 'NORTH',  1, 15),
(16, 'NORTH',  1, 16),
(17, 'NORTH',  1, 17),
(18, 'NORTH',  1, 18),
(19, 'NORTH',  1, 19),
(20, 'NORTH',  1, 20),
(21, 'NORTH',  1, 21),
(22, 'NORTH',  1, 22),
(23, 'NORTH',  1, 23),
(24, 'NORTH',  1, 24),
(25, 'NORTH',  1, 25),
(26, 'NORTH',  1, 26),
(27, 'NORTH',  1, 27),
(28, 'NORTH',  1, 28),
(29, 'NORTH',  1, 29),
(30, 'NORTH',  1, 30),
(31, 'NORTH',  1, 31),
(32, 'NORTH',  1, 32),
(33, 'NORTH',  1, 33),
(34, 'NORTH',  1, 34),
(35, 'NORTH',  1, 35),
(36, 'NORTH',  1, 36),
(37, 'NORTH',  1, 37),
(38, 'NORTH',  1, 38),
(39, 'SOUTH',  1, 1),
(40, 'SOUTH',  1, 2),
(41, 'SOUTH',  1, 3),
(42, 'SOUTH',  1, 4),
(43, 'SOUTH',  1, 5),
(44, 'SOUTH',  1, 6),
(45, 'SOUTH',  1, 7),
(46, 'SOUTH',  1, 8),
(47, 'SOUTH',  1, 9),
(48, 'SOUTH',  1, 10),
(49, 'SOUTH',  1, 11),
(50, 'SOUTH',  1, 12),
(51, 'SOUTH',  1, 13),
(52, 'SOUTH',  1, 14),
(53, 'SOUTH',  1, 15),
(54, 'SOUTH',  1, 16),
(55, 'SOUTH',  1, 17),
(56, 'SOUTH',  1, 18),
(57, 'SOUTH',  1, 19),
(58, 'SOUTH',  1, 20),
(59, 'SOUTH',  1, 21),
(60, 'SOUTH',  1, 22),
(61, 'SOUTH',  1, 23),
(62, 'SOUTH',  1, 24),
(63, 'SOUTH',  1, 25),
(64, 'SOUTH',  1, 26),
(65, 'SOUTH',  1, 27),
(66, 'SOUTH',  1, 28),
(67, 'SOUTH',  1, 29),
(68, 'SOUTH',  1, 30),
(69, 'SOUTH',  1, 31),
(70, 'SOUTH',  1, 32),
(71, 'SOUTH',  1, 33),
(72, 'SOUTH',  1, 34),
(73, 'SOUTH',  1, 35),
(74, 'SOUTH',  1, 36),
(75, 'SOUTH',  1, 37),
(76, 'SOUTH',  1, 38),
(77, 'WEST', 1, 1),
(78, 'WEST', 1, 2),
(79, 'WEST', 1, 3),
(80, 'WEST', 1, 4),
(81, 'WEST', 1, 5),
(82, 'WEST', 1, 6),
(83, 'WEST', 1, 7),
(84, 'WEST', 1, 8),
(85, 'WEST', 1, 9),
(86, 'WEST', 1, 10),
(87, 'WEST', 1, 11),
(88, 'WEST', 1, 12),
(89, 'WEST', 1, 13),
(90, 'WEST', 1, 14),
(91, 'WEST', 1, 15),
(92, 'WEST', 1, 16),
(93, 'WEST', 1, 17),
(94, 'WEST', 1, 18),
(95, 'WEST', 1, 19),
(96, 'WEST', 1, 20),
(97, 'WEST', 1, 21),
(98, 'WEST', 1, 22),
(99, 'WEST', 1, 23),
(100,'WEST', 1, 24),
(101,'WEST', 1, 25),
(102,'WEST', 1, 26),
(103,'WEST', 1, 27),
(104,'WEST', 1, 28),
(105,'WEST', 1, 29),
(106,'WEST', 1, 30),
(107,'WEST', 1, 31),
(108,'WEST', 1, 32),
(109,'WEST', 1, 33),
(110,'WEST', 1, 34),
(111,'WEST', 1, 35),
(112,'WEST', 1, 36),
(113,'WEST', 1, 37),
(114,'WEST', 1, 38),
(115, 'NORTH', 2, 1),
(116, 'NORTH', 2, 2),
(117, 'NORTH', 2, 3),
(118, 'NORTH', 2, 4),
(119, 'NORTH', 2, 5),
(120, 'NORTH', 2, 6),
(121, 'NORTH', 2, 7),
(122, 'NORTH', 2, 8),
(123, 'NORTH', 2, 9),
(124, 'NORTH', 2, 10),
(125, 'NORTH', 2, 11),
(126, 'NORTH', 2, 12),
(127, 'NORTH', 2, 13),
(128, 'NORTH', 2, 14),
(129, 'NORTH', 2, 15),
(130, 'NORTH', 2, 16),
(131, 'NORTH', 2, 17),
(132, 'NORTH', 2, 18),
(133, 'NORTH', 2, 19),
(134, 'NORTH', 2, 20),
(135, 'NORTH', 2, 21),
(136, 'NORTH', 2, 22),
(137, 'NORTH', 2, 23),
(138, 'NORTH', 2, 24),
(139, 'NORTH', 2, 25),
(140, 'NORTH', 2, 26),
(141, 'NORTH', 2, 27),
(142, 'NORTH', 2, 28),
(143, 'NORTH', 2, 29),
(144, 'NORTH', 2, 30),
(145, 'NORTH', 2, 31),
(146, 'NORTH', 2, 32),
(147, 'NORTH', 2, 33),
(148, 'NORTH', 2, 34),
(149, 'NORTH', 2, 35),
(150, 'NORTH', 2, 36),
(151, 'NORTH', 2, 37),
(152, 'NORTH', 2, 38)
SET IDENTITY_INSERT locationTbl OFF
SELECT * FROM locationTbl 
ORDER BY fieldColumn, fieldRow

INSERT INTO plantTypeTbl (	plantName, plantBreed, daysToHarvest, [description] )
VALUES 
('Cilantro', 'Common', 45 , 'The highly aromatic, rich and spicy Cilantro adds the perfect flavor to any cuisine! This plant is ideal for harvesting both the cilantro leaves and coriander seeds. The unique flavor of this cilantro is bold and bright with a touch of citrus undertones.'),
('Cilantro', 'Coriandrum sativum', 80 , 'Coriander is an annual herb in the family Apiaceae. It is also known as Chinese parsley, and in the United States the stems and leaves are usually called cilantro'),
('Corn', 'Bilicious Hybrid', 78, 'Bi-Licious is an excellent mid-season hybrid with bi-colored kernels maturing in 75 or more days. Ears are 8 1/2 inches with 16 rows of kernels. Corn is a warm season crop. Pollination is essential for success so corn needs to be planted in a block of three rows of 12-24 plants (rather than one row).'),
('Kohlrabi', 'Early White Vienna', 55, 'Round, above-ground "bulbs" with light green, smooth skin have creamy white, tender flesh. Flavor is mild, sweet, turnip-like. Superb raw or steamed. Ready for harvest 55 days from seed sowing.'),
('Hot Pepper', 'Jalapeno Early', 80, 'Cooks Garden Favorite. Dark green, pungent 3" hot peppers are excellent fresh or pickled. Zesty flavor is great in Mexican dishes.'),
('Watermelon', 'Orange Tendersweet', 90, 'This heirloom favorite features luscious, bright orange flesh. Tender and very sweet, the oblong striped fruits grow to 35 lb.'),
('Cucumber', 'PickelBush', 70, 'Burpee-bred Picklebush has unbelievably compact vines that get only 2 long. White-spined fruits have classic pickle look, deep green with paler stripes. Up to 4 1/2" long, 1 1/2" across at maturity, but use them at any size. Very productive and tolerant to powdery mildew and cucumber mosaic virus.'),
('Tomato', 'Roma ', 80, 'Compact plants produce paste-type tomatoes resistant to Verticillium and Fusarium wilts. Meaty interiors and few seeds. GARDEN HINTS: Fertilize when first fruits form to increase yield. Water deeply once a week during very dry weather. We searched the world to find the best organic seed-Burpee fully guarantees that not a drop of synthetic chemicals was used to make these excellent seeds.'),
('Sweet Pepper', 'Carnival Blend', 75 , 'When you plant a packet, some will turn out gold or orange and others will be red, purple or ivory. Most start out green and are tasty as soon as they reach full size; a few weeks later, their full ripe color will show. These are all classic big bell hybrids: California Wonder, Diamond, Golden California Wonder, Orange Sun and Purple Beauty.'),
('Hot Pepper', 'Salsa Blend', 75 , 'Five different kinds of hot peppers! Includes Hungarian Wax, Anaheim Chili, Long Slim Red Cayenne, Ancho (Poblano) and Jalapeno M. Days to maturity are from time plants are set in garden. For transplants add 8-10 weeks. Space plants 18-24" apart.'),
('Watermelon', 'Jubilee', 90, 'Jubilee watermelon has a green-striped rind and an oblong shape, with red flesh. Full-sized Jubilee watermelons range in weight from 25 pounds to as heavy as 45 pounds. When ripe, these melons are characterized by a tough rind and sweet flesh. Jubilee watermelons are resistant to the soilborne disease fusarium wilt.'),
('Eggplant', 'Black Beauty', 70, 'Over 100 years old, this 1902 Burpee introduction was an immediate hit because the plants ripened perfect fruits dramatically earlier than other varieties. It became the common market eggplant of today. Harvested fresh, however, makes all the difference.'),
('Tomato', 'Best Boy Hybrid', 80, 'Burpee Best Boy Hybrid. 70 days to harvest. This Burpee tomato was born to be a star. Early maturity produces large, firm fruits on a compact plant.'),
('Cucumber', 'Poinsett', 70, '70 days. Poinsett 76 are straight, dark green, non-bitter and delightfully crisp cucumbers. They are 7 – 8” long with a 2 – 2½” diameter. With the market dominated by hybrids, Poinsett 76 is one of the best open-pollinated, classic slicing cucumbers. Very popular in the 1980’s & 1990’s, we became impressed with its overall vigor, productivity and disease resistance. Resistant to many common diseases that plague cucumber plants, including powdery & downy mildew, anthracnose, angular leaf spot, and scab. If you have trouble growing cucumbers, give these a whirl!  '),
('Squash', 'Scallop', 54, 'This All-America Selections winner is a miniature patty pan type with light green 1-3" fruits thats meatier than most patty pans. Distinctive, delicious, sweet flavor and vigorous, early-bearing plants. Pick over a long period. Summer squash and zucchini ripen early and are highly productive. The bush type plants take little space. After danger of frost, sow 3 to 4 seeds in groups 3 to 4 apart or sow 6" apart in rows, later thinning to 3 apart'),
('Melon', 'Honey Rock', 80, 'The Honeyrock melon is an heirloom variety of the cantaloupe, developed at Michigan State University. The Honeyrock melon is an heirloom variety of the cantaloupe, developed at Michigan State University. It is typically sweeter and firmer than cantaloupe melons.'),
('Squash', 'Blue Hubbard', 120, 'A beloved heirloom with a hard, bumpy, blue-green shell. A fall tradition at New England roadside stands. Medium-dry, medium-sweet yellow flesh. Avg. weight: 12–15 lb., with some larger. Avg. yield: 1 or sometimes 2 fruits/plant.'),
('Beet', 'Detroit Dark Red', 65, 'This classic variety produces early, very dark red and extremely sweet roots up to 3" across. Its good fresh, canned or frozen. We searched the world to find the best organic seed-Burpee fully guarantees that not a drop of synthetic chemicals was used to make these excellent seeds. Certified Organic Seed.'),
('Cantaloupe', 'Hearts of Gold', 80, 'These are beautiful melons with luscious deep-orange golden flesh that is sweet, juicy and fragrant. Rinds are thin, heavily netted and medium ribbed. Vigorous, prolific plants bear nearly round, medium-sized, 2-3 lb.'),
('Watermelon', 'Sugar Baby', 90, 'Round fruits, 6–8" in diameter, averaging 8–10 lb. Ripe melons are almost black. Good flavor. Tough rinds resist cracking. The standard of "icebox" melons for many years.'),
('Cucumber', 'Boston Pickling', 70, 'Boston Pickling cucumbers are a high yielding plant with a continuous harvest! Just like its name, the Boston Pickling is great for making pickles! This cucumber will grow to 3″ long and smooth with black spines. Cucumbers can be grown for fresh eating, pickling and more.'),
('Squash', 'Waltham Butternut', 120, 'Fall and winter, this is a delicious butternut with improved fruit uniformity and increased yields. Interior is solid and dry. Pick young and use like summer squash or let mature to 6 lbs. Excellent for storing. Ready about 85 days after sowing.'),
('Squash', 'Table Queen', 120, 'The flesh of this heirloom acorn is a sweet golden yellow that turns more orange in storage and the rind is dark green and ribbed. Fruits grow to 6". GARDEN HINTS: Leave on vine until fully mature. Harvest before frost, leaving part of the stem attached to the fruit. Store for winter use at 45-55 F in a dry place.'),
('Squash', 'Vegetable Spaghetti', 120, 'Medium-sized, 3-4 lb. oblong fruits. The fruits interior is ready for serving like spaghetti 100 days after seed is sown. Can be stored several months in a cool, dry place. GARDEN HINTS: Cultivate or mulch to control weeds. Fertilize when fruits form to increase yield. CULINARY HINTS: Boil entire fruit about 20 minutes, open, remove seeds and fluff flesh out of shell with a fork for spaghetti-like appearance. Serve with spaghetti sauce or season to taste.'),
('Tomato', 'Striped Stuffer', 85, 'Solanum lycopersicum. Open Pollinated. Plant produces high yields of 5 to 7 oz bi-colored red tomatoes with golden orange stripes. These pepper shaped tomatoes are perfect for stuffing, garnishes, or culinary creations. They are completely hollow. Great for making tuna stuffers. It will keep up to 4 weeks in the refrigerator. Excellent choice for home gardens. A heirloom variety. Disease Resistant: PM. Indeterminate.'),
('Squash', 'Acorn', 100, 'Productive plants bear five large 5", dark green fruits. Orange-yellow flesh is sweet, nutty and has a smooth texture. Burpee bred and proven tops for performance, flavor, and wide adaptability. 25 seeds per packet, will plant 6 groups.'),
('Salsify', 'Mammoth Sandwich Island', 120, 'Trogopogon porrifolius. AKA the Oyster Plant, the Vegetable Oyster. Popular in the U.S. in the 1700s, this ancient Mediterranean native is coming back into favor now. Looking like a whiskered, tan-white forked Carrot, it tastes like a cross between Artichoke hearts and oysters. Direct sow in a deeply dug bed in full sun as soon as the ground can be worked in the spring. Water well until the sprouts emerge. Harvest in late fall (although it may overwinter in milder climates).'),
('Cucumber', 'Straight Eight', 65, 'This heirloom, All-America Selections winner is a cuke for all seasons. Pick when 8" long for top flavor. For perfect cukes, grow them on a fence or our space-saving Trellis Netting. Sow seeds 6" apart in rows, or plant 5 or 6 seeds in groups (hills) 4 to 5 apart.'),
('Pumpkin', 'Small Sugar', 105, 'Small Sugar is even better for pies than its larger cousin Connecticut Field pumpkin. When Mr. Burpee offered it in 1887 he said: "A very prolific and handsome little pumpkin; usual size about 10" in diameter; skin is a deep orange-yellow. It is very fine-grained, sweet and sugary, and keeps well."'),
('Mustard', 'Old Fashioned', 30, 'A mild-flavored mustard producing large, broad, rich green leaves of appetizing pungency. Greens may be steamed, brazed or cooked in broth. Easily grown in the north.'),
('Eggplant', 'Long Purple', 65, 'The dark purple fruits are best used before they are 8 to 10" long. Each plant grows to 24 to 30" and produces 8 or more eggplants. We searched the world to find the best organic seed-Burpee fully guarantees that not a drop of synthetic chemicals was used to make these excellent seeds. Certified Organic.'),
('Dill', 'Mammoth Long Island', 70, 'Mammoth Long Island Dill is known to be the best type of dill for pickling. This plant is quick to mature and can be harvested for its seeds and leaves. Dill is a hardy, tall annual that is a member of the carrot family. It grows easily and has a strong, wonderful aroma.'),
('Parsnip', 'Harris Model', 95, 'Pure white perfectly straight roots. The slightly sweet flavor is unique in our experience. Store well and should comprise at least a small part of every northern garden. In the North, leave them in the garden until spring. It gives you a sweet treat to look forward to all winter. Dig them as soon as you can after thaw. If they are left for a few weeks they develop a lot of little white roots and start to become woody.'),
('Parsnip', 'Hollow Crown', 100, 'This parsnip develops a sweet, nutty flavor after frost. Mature roots are 12" long and 3" thick. Does best in deeply prepared soil.'),
('Borage', 'Common', 56, 'While not as common as thyme or basil, borage herb (Borago officinalis) is a unique plant for the culinary garden. It grows quickly as an annual but will colonize a corner of the garden by self-seeding and reappearing year after year. ... The borage plant may grow 12 or more inches wide in a tall bushy habit'),
('Mustard', 'Southern Giant Curled', 30, 'With crumpled, frilled edges, the bright green leaves impart a mild, mustardy flavor. Served raw, the young leaves are tasty in salads-theyre also delicious lightly stir-fried or sauteed. Superb candidate for freezing or canning. Cold-resistant and slow to bolt, the large, upright and vigorous plants spread to 18-24". Harvest young leaves in about 50 days or more mature leaves in about 70.'),
('Melon', 'Hales Best Jumbo', 100, 'Hales Best Jumbo was developed by a Japanese market gardener in California around 1920. It became widely popular because it combined excellent flavor with earliness. Its a beautiful oval melon with deep green skin and golden netting. The flesh is an appealing salmon color, aromatic and sweet.'),
('Watermelon', 'Charleston Grey', 105, 'Flesh is red, crisp, fiberless and delicious; skin is light greenish gray. Resistant to fusarium wilt, anthracnose and sunburn. Ready for harvest 85 days after sowing. GARDEN HINTS: For early fruiting and to overcome a short growing season, start seeds in a warm, well-lighted indoor area 3 to 4 weeks before last spring frost. Before transfer to garden, accustom plants to outdoor conditions by moving to a sheltered area outside for a week. Grow on plastic mulch to control weeds, conserve soil moisture and protect fruit by keeping it off the ground.'),
('Bean', 'Fava - Broad Windsor', 85, 'The plants of Broad Windsor fava beans reach thirty-six to forty-eight inches tall, are upright, and non-branching. The five to eight inch long pods each contain five to seven seeds. The seeds are large, about the diameter of a U.S. quarter dollar coin, and a little over twice as thick.'),
('Coriander', 'Long Standing', 42, 'Also called Chinese parsley, cilantro has a thousand uses in the kitchen. Long Standing in particular has excellent flavor, improved leafiness and, as the name infers, it is slow-to-bolt. Add a sprig to chicken soup or add chopped leaves to Mexican, Caribbean, or Asian dishes. The crushed seeds add intriguing flavor to stews, beans, and cookies. Can be grown indoors for fresh cilantro leaves year-round. Cilantro grows best in cool temperatures.'),
('Okra', 'Red Burgundy', 60, 'When cooked, the leaves of this hibiscus relative turn a deep lovely shade of purple. Gorgeous 3-5 ornamental plants produce high numbers of tender 6-8" pods. Theres a pretty contrast between the plants green leaves against the burgundy stems, branches, leaf ribs and fruits-and a pretty display of yellow-cream flowers. For optimal texture and flavor, harvest often when the pods are young about 3" long, in about 49-60 days.'),
('Cumin', 'Common', 120, 'Cumin is the dried seed of the herb Cuminum cyminum, a member of the parsley family. The cumin plant grows to 30–50 cm (12–20 in) tall and is harvested by hand. It is an annual herbaceous plant, with a slender, glabrous, branched stem that is 20–30 cm (8–12 in) tall and has a diameter of 3–5 cm (​1 1⁄4–2 in).'),
('Thyme', 'Winter', 28, 'Good flavor and yield. Classic culinary and ornamental herb. Small, round to needle-shaped evergreen leaves on woody stems. Mulch in cold winter climates. Perennial in Zones 5–8.'),
('Yarrow', 'White', 90, 'Achillea millefolium (White Yarrow) is a graceful perennial wildflower which produces an abundance of huge, flat clusters, 5 in. Both flowers and foliage are attractive and long-lasting, making White Yarrow a wonderful garden plant and a great choice for prairie or meadow plantings.'),
('Squash', 'Dark Green Zucchini', 120, 'Squash Dark Green Zucchini is a variety that produces exceptionally high yields of flavorful zucchini. When mature, it can be up to 10 to 12 inches long. Ideal for multiple cooking dishes and baked goods such as cakes, breads, and muffins,this variety is a delight in the kitchen.'),
('Parsley', 'Moss Curled', 75, 'This culinary standard is easy to grow and tolerates light frost. The uniform, dark green, medium-fine curled leaves can be used as a garnish or a salad or entree ingredient. Multiple cuttings per season are possible from one planting.'),
('Bean', 'Lima', 85, 'Phaseolus lunatus, commonly known as the lima bean, butter bean, sieva bean, Double Bean or Madagascar bean, is a legume grown for its edible seeds or beans.'),
('Okra', 'Perkins Long Pod', 55, 'Also known as Perkins Mammoth Long Pod, the pods are bright green, four to six inches long and borne on strong plants that can reach five to six feet in height. It is a good choice for pickling, canning, and used in soups and gumbo. '),
('Amaranth', 'Red Garnet', 120, 'The plants of Red Garnet amaranth are a beautiful maroonish-red color with fuchsia-red flower heads making it an attractive addition to your ornamental gardens. ... Harvested at 20 to 30 days, its young leaves are tender and mild and make a nice addition to a mixed greens salad.'),
('Fennel', 'Florence', 115, 'Also called Florence Fennel or Finuccio, it is easy to grow and very hardy, lasting well after the first frost. With bright green, fern-like leaves and aromatic yellow flowers, this plant will grow three to four feet tall. Plant it in the back of the herb garden or in your vegetable garden.'),
('Basil', 'Italian Large Leaf', 75, 'Large plant with medium-dark green leaves up to 4" long. Compared to Genovese, the scent and taste are sweeter. Ht. 24-30". '),
('Caraway', 'Common', 28, 'Caraway, also known as meridian fennel and Persian cumin, is a biennial plant in the family Apiaceae, native to western Asia, Europe, and North Africa. The plant is similar in appearance to other members of the carrot family, with finely divided, feathery leaves with thread-like divisions, growing on 20–30 cm stems. '),
('Watermelon', 'Black Diamond', 100, 'Binomial Name: Citrullus lanatus. Watermelon Varieties: Black Diamond, Jubilee, Sugar Baby. Black Diamond Watermelon is sometimes described as the king of the garden, sometimes weighing 50 pounds or more. The bright red flesh is noted for its juiciness and sweet taste.'),
('Pea', 'Green Arrow', 70, 'he Green Arrow pea plant grows in a vining habit but is small as peas go, usually reaching only 24 to 28 inches (61-71 cm.) in height. It is resistant to both fusarium wilt and powdery mildew. Its pods usually grow in pairs and reach maturity in 68 to 70 days.'),
('Pumpkin', 'Mammoth Gold', 120, 'Mammoth Gold seeds are great producers of giant pumpkins that can routinely reach weights of up to 60 pounds or more. Grown in gardens since the late 1800s, this one is a keeper!'),
('Tomato', 'Floradade', 80, 'The Floradade Tomato is a delicious, bright red variety that has a great ability to withstand heat and produce high yields! This variety was introduced by the University of Florida in 1976. This tomato plant produces smooth, 5-7 ounces sized tomatoes with slightly deep globes that have red with green shoulders.'),
('Tomato', 'Costoluto Genovese', 75, 'The Costoluto Genovese tomato is an Italian heirloom tomato variety. Its heavily lobed and often convoluted shape is indicative of early nineteenth century tomato varieties, but makes an oddity in todays vegetable garden. The Costoluto Genoveses stellar flavor is intense and acidic.'),
('Tomato', 'Brandywine Red', 75, 'Flavorful but not acidic, it is a large-lobed, beefsteak-shaped tomato with a thin, pinkish-red skin. Very vigorous. Best if staked, caged, or trellised. Perfect for slicing. Certified Organic by Oregon Tilth'),
('Tomato', 'Ace 55', 80, 'Large, deep red fruit with low acid content–one of the few red tomatoes to be able to make that claim. Crack-resistant. Heavy foliage shades fruit to protect from it sunburn. Plant is not overly tall, but still benefits from staking. Good for containers. This tried and true variety is resistant to verticillium wilt (V), fusarium wilt (F), and alternaria stem canker (ASC).'),
('Tomato', 'Marglobe Improved', 80, 'Marglobe Improved Tomato. (VF) This highly adaptable, tasty, old favorite produces high yields of globe-shaped fruits on uniform vines. Large fruits are uniform as well, very sweet and thick-walled. Tolerant to Fusarium Wilt.'),
('Tomato', 'San Marzano', 75, 'The long, blocky fruits mature with a small, discreet seed cavity that can be scooped out, leaving all meat. This means much less boiling to get a first class paste. The shape is also good for canning, and excellent for drying.'),
('Tomato', 'Yellow Pear', 75, 'Possibly the most popular yellow heirloom variety of tomato, the Yellow Pear gets its name from its color and shape. This variety dates back to the 1800s and is a vigorous indeterminate. It produces generously with an abundance of small, yellow pear-shaped tomatoes that are sweet, but mild in flavor.'),
('Tomato', 'Rutgers', 80, 'The legendary Jersey tomato, introduced in 1934, is a cross between J.T.D. (an old New Jersey variety from the Campbell Soup Co.) and Marglobe. Its flavor, both for slicing and cooking, is still unequaled. Red fruits are slightly flattened. Tall vines, Fusarium resistance.'),
('Tomato', 'Marion', 75, 'Solanum lycopersicum. ... Plant produces high yields of 6 to 8 oz red tomatoes. Perfect for salads, slicing, and sandwiches. A Rutgers type tomato, but earlier, larger, and more disease resistant.'),
('Tomato', 'Beefsteak Red', 80, 'A beef tomato or beefsteak tomato is one of the largest varieties of cultivated tomatoes, some weighing 450 grams or more. Most are pink or red with numerous small seed compartments distributed throughout the fruit, sometimes displaying pronounced ribbing similar to ancient pre-Columbian tomato cultivars.'),
('Tomato', 'Azoyehka', 80, 'Azoychka is a yellow Russian beefsteak heirloom tomato. The regular multi-locular structure distinguishes it from brandywine types.'),
('Tomato', 'Chocolate Stripes', 80, 'One of the "Top 3" "best tasting" tomatoes in several years of TomatoFest events by attendees and the events tasting panel and voted on by thousands of TomatoFest customers purchasing seeds. Large, indeterminate, regular-leaf tomato plants that yield a plentiful crop of 3-4 inch, mahogany colored with dark, olive green-striping (similar to black zebra).  Fruits have delicious, complex, rich, sweet, earthy tomato flavors. Chocolate Stripe, another desirable black tomato, is an excellent tomato and a fine choice for your tomato garden. Produces well into the autumn. A great sandwich tomato and salad tomato.'),
('Tomato', 'Cherokee Purple', 80, 'Cherokee Purple is the name of a cultivar of tomato that develops a fruit with a deep, dusky-rose color while maintaining a somewhat greenish hue near the stem when mature for eating. The deep crimson interior and clear skin combination give it its distinctive color.'),
('Tomato', 'Golden Jubilee', 80, 'The Jubilee cultivar of tomato is heavy yielding, low acid, with golden fruit that grow on indeterminate vines. It was released by Burpee Seeds in 1943. '),
('Tomato', 'Homestead 24', 80, 'Originally released as Homestead No. 24, it sets fruit under a wide range of conditions, making it popular the world over. The plants are large with heavy foliage and produce seven to eight ounce red fruits that are meaty, firm, and consistently uniform. It is resistant to fusarium wilt.'),
('Squash', 'Cocozelle', 59, 'This Italian zucchini is long and cylindrical. Young fruits are dark green with light-green stripes and the flesh is greenish-white and firm. Fruits grow 10-12 in. long and become yellow when mature, but best quality when harvested at 6-8 in.'),
('Bean', 'Blue Lake', 55, 'Blue Lake Bush beans are prolific plants that feature 5- to 6-inch-long, straight, stringless snap beans on 24-inch-tall bushy vines. This heirloom green bean, like other bush and pole beans, is an easy-to-grow annual, thriving in your garden over a single growing season'),
('Pea', 'Little Marvel', 60, 'The variety of pea Little Marvel is a compact plant that will produce a lot of tasty peas. Little Marvel garden pea was introduced in the early 1900s by Sutton and Sons of Reading, England. It is a cross of Chelsea Gem and Suttons A-1. ... This hardy plant grows 30 inches (76 cm.) tall and produces 3-inch (7.6 cm.)'),
('Bean', 'Golden Wax', 70, 'Growing on an upright bush, bright yellow, stringless pods of 4-5" are easy to spot among green foliage. Delicious buttery flavor. Certified Organic Seed.'),
('Pea', 'Sugar Ann', 55, 'Sugar Ann is a string-less pea that was an All-American Selections winner in 1984. The pods are 3 inches long (7.6 cm.) and bright green. It is a vine type, but the vines are short and compact and rarely need staking. Snap peas are plumper and thicker than snow peas, with a pleasant bite.'),
('Corn', 'Golden Bantam', 80, 'This variety made yellow sweet corn popular. When Burpee introduced it in 1902, people only wanted white corn, as white signified refinement and quality. It was created by a skilled gardener in Greenfield, Massachusetts who loved to have the earliest corn in town. Golden Bantam quickly rose to the top since it sprouted in cool soil better than all other corns of the time, and growers could make big money with it. The stalks are only 5 ft. tall and often bear two 5 1/2 to 6 1/2" long ears apiece. For old- fashioned corn flavor and early plantings, its still outstanding.')
SELECT * FROM plantTypeTbl

SET IDENTITY_INSERT plantTbl ON
INSERT INTO plantTbl  (plantId, plantTypeId, locationId, harvestId, tendedId) VALUES (1,   1,  1,  1,  1),
(2,   2,  2,  2,  2),
(3,   3,  3,  3,  3),
(4,   4,  4,  4,  4),
(5,   5,  5,  5,  5),
(6,   6,  6,  6,  6),
(7,   7,  7,  7,  7),
(8,   8,  8,  8,  8),
(9,   9,  9,  9,  9),
(10,  10, 10, 10, 10),
(11,  11, 11, 11, 11),
(12,  12, 12, 12, 12),
(13,  13, 13, 13, 13),
(14,  14, 14, 14, 14),
(15,  15, 15, 15, 15),
(16,  16, 16, 16, 16),
(17,  17, 17, 17, 17),
(18,  18, 18, 18, 18),
(19,  19, 19, 19, 19),
(20,  20, 20, 20, 20),
(21,  21, 21, 21, 21),
(22,  22, 22, 22, 22),
(23,  23, 23, 23, 23),
(24,  24, 24, 24, 24),
(25,  25, 25, 25, 25),
(26,  26, 26, 26, 26),
(27,  27, 27, 27, 27),
(28,  28, 28, 28, 28),
(29,  29, 29, 29, 29),
(30,  30, 30, 30, 30),
(31,  31, 31, 31, 31),
(32,  32, 32, 32, 32),
(33,  33, 33, 33, 33),
(34,  34, 34, 34, 34),
(35,  35, 35, 35, 35),
(36,  36, 36, 36, 36),
(37,  37, 37, 37, 37),
(38,  38, 38, 38, 38),
(39,  39, 39, 39, 39),
(40,  40, 40, 40, 40),
(41,  41, 41, 41, 41),
(42,  42, 42, 42, 42),
(43,  43, 43, 43, 43),
(44,  44, 44, 44, 44),
(45,  45, 45, 45, 45),
(46,  46, 46, 46, 46),
(47,  47, 47, 47, 47),
(48,  48, 48, 48, 48),
(49,  49, 49, 49, 49),
(50,  50, 50, 50, 50),
(51,  51, 51, 51, 51),
(52,  52, 52, 52, 52),
(53,  53, 53, 53, 53),
(54,  54, 54, 54, 54),
(55,  55, 55, 55, 55),
(56,  56, 56, 56, 56),
(57,  57, 57, 57, 57),
(58,  58, 58, 58, 58),
(59,  59, 59, 59, 59),
(60,  60, 60, 60, 60),
(61,  61, 61, 61, 61),
(62,  62, 62, 62, 62),
(63,  63, 63, 63, 63),
(64,  64, 64, 64, 64),
(65,  65, 65, 65, 65),
(66,  66, 66, 66, 66),
(67,  67, 67, 67, 67),
(68,  68, 68, 68, 68),
(69,  69, 69, 69, 69),
(70,  70, 70, 70, 70),
(71,  71, 71, 71, 71),
(72,  72, 72, 72, 72),
(73,  73, 73, 73, 73),
(74,  74, 74, 74, 74),
(75,  75, 75, 75, 75),
(76,  76, 76, 76, 76),
(77,  1,  77, 77, 77),
(78,  2,  78, 78, 78),
(79,  3,  79, 79, 79),
(80,  4,  80, 80, 80),
(81,  5,  81, 81, 81),
(82,  6,  82, 82, 82),
(83,  7,  83, 83, 83),
(84,  8,  84, 84, 84),
(85,  9,  85, 85, 85),
(86,  10, 86, 86, 86),
(87,  11, 87, 87, 87),
(88,  12, 88, 88, 88),
(89,  13, 89, 89, 89),
(90,  14, 90, 90, 90),
(91,  15, 91, 91, 91),
(92,  16, 92, 92, 92),
(93,  17, 93, 93, 93),
(94,  18, 94, 94, 94),
(95,  19, 95, 95, 95),
(96,  20, 96, 96, 96),
(97,  21, 97, 97, 97),
(98,  22, 98, 98, 98),
(99,  23, 99, 99, 99),
(100, 24, 100,100,100),
(101, 25, 101,101,101),
(102, 26, 102,102,102),
(103, 27, 103,103,103),
(104, 28, 104,104,104),
(105, 29, 105,105,105),
(106, 30, 106,106,106),
(107, 31, 107,107,107),
(108, 32, 108,108,108),
(109, 33, 109,109,109),
(110, 34, 110,110,110),
(111, 35, 111,111,111),
(112, 36, 112,112,112),
(113, 37, 113,113,113),
(114, 38, 114,114,114),
(115, 39, 115,115,115),
(116, 40, 116,116,116),
(117, 41, 117,117,117),
(118, 42, 118,118,118),
(119, 43, 119,119,119),
(120, 44, 120,120,120),
(121, 45, 121,121,121),
(122, 46, 122,122,122),
(123, 47, 123,123,123),
(124, 48, 124,124,124),
(125, 49, 125,125,125),
(126, 50, 126,126,126),
(127, 51, 127,127,127),
(128, 52, 128,128,128),
(129, 53, 129,129,129),
(130, 54, 130,130,130),
(131, 55, 131,131,131),
(132, 56, 132,132,132),
(133, 57, 133,133,133),
(134, 58, 134,134,134),
(135, 59, 135,135,135),
(136, 60, 136,136,136),
(137, 61, 137,137,137),
(138, 62, 138,138,138),
(139, 63, 139,139,139),
(140, 64, 140,140,140),
(141, 65, 141,141,141),
(142, 66, 142,142,142),
(143, 67, 143,143,143),
(144, 68, 144,144,144),
(145, 69, 145,145,145),
(146, 70, 146,146,146),
(147, 71, 147,147,147),
(148, 72, 148,148,148),
(149, 73, 149,149,149),
(150, 74, 150,150,150),
(151, 75, 151,151,151),
(152, 76, 152,152,152)
SET IDENTITY_INSERT plantTbl OFF
SELECT * FROM plantTbl 

SET IDENTITY_INSERT harvestTbl ON
INSERT INTO harvestTbl (harvestId, plantId, recordedDate, numHarvest, numWaste) 
VALUES 
(1,		1,		 '6/10/2019', 8, 18),
(2,		2,		 '11/15/2019', 51, 3),
(3,		3,		 '12/10/2019', 48, 8),
(4,		4,		 '11/13/2019', 86, 16),
(5,		5,		 '10/28/2019', 88, 6),
(6,		6,		 '2/5/2020', 62, 14),
(7,		7,		 '12/19/2019', 93, 3),
(8,		8,		 '9/27/2019', 64, 1),
(9,		9,		 '8/6/2019', 55, 1),
(10,  10,    '4/16/2020', 1, 14),
(11,  11,    '12/30/2019', 31, 5),
(12,  12,    '3/11/2020', 58, 0),
(13,  13,    '9/6/2019', 49, 18),
(14,  14,    '6/6/2019', 83, 15),
(15,  15,    '7/20/2019', 28, 16),
(16,  16,    '10/27/2019', 11, 8),
(17,  17,    '2/4/2020', 88, 11),
(18,  18,    '5/3/2020', 89, 6),
(19,  19,    '9/8/2019', 44, 9),
(20,  20,    '11/5/2019', 7, 0),
(21,  21,    '3/26/2020', 57, 17),
(22,  22,    '7/13/2019', 32, 20),
(23,  23,    '9/25/2019', 93, 17),
(24,  24,    '9/21/2019', 49, 13),
(25,  25,    '7/12/2019', 33, 5),
(26,  26,    '11/20/2019', 16, 12),
(27,  27,    '5/30/2019', 20, 15),
(28,  28,    '6/4/2019', 25, 11),
(29,  29,    '8/24/2019', 81, 3),
(30,  30,    '5/14/2019', 68, 6),
(31,  31,    '1/11/2020', 75, 15),
(32,  32,    '10/9/2019', 83, 1),
(33,  33,    '12/4/2019', 13, 17),
(34,  34,    '5/12/2019', 27, 8),
(35,  35,    '11/1/2019', 27, 3),
(36,  36,    '12/25/2019', 11, 7),
(37,  37,    '11/29/2019', 82, 15),
(38,  38,    '12/28/2019', 92, 17),
(39,  39,    '12/5/2019', 86, 17),
(40,  40,    '1/22/2020', 6, 2),
(41,  41,    '11/9/2019', 50, 11),
(42,  42,    '10/3/2019', 1, 11),
(43,  43,    '1/21/2020', 95, 2),
(44,  44,    '11/12/2019', 84, 11),
(45,  45,    '12/27/2019', 6, 18),
(46,  46,    '2/19/2020', 60, 19),
(47,  47,    '1/18/2020', 28, 16),
(48,  48,    '3/22/2020', 100, 5),
(49,  49,    '11/29/2019', 10, 10),
(50,  50,    '4/4/2020', 69, 16),
(51,  51,    '10/25/2019', 58, 4),
(52,  52,    '2/5/2020', 92, 0),
(53,  53,    '5/26/2019', 94, 12),
(54,  54,    '1/11/2020', 32, 12),
(55,  55,    '4/14/2020', 78, 9),
(56,  56,    '1/26/2020', 88, 4),
(57,  57,    '5/16/2019', 29, 5),
(58,  58,    '2/17/2020', 84, 17),
(59,  59,    '10/26/2019', 65, 16),
(60,  60,    '10/6/2019', 45, 19),
(61,  61,    '12/13/2019', 60, 16),
(62,  62,    '8/3/2019', 68, 12),
(63,  63,    '5/10/2019', 10, 0),
(64,  64,    '1/1/2020', 69, 6),
(65,  65,    '9/19/2019', 14, 18),
(66,  66,    '7/3/2019', 65, 19),
(67,  67,    '6/27/2019', 83, 6),
(68,  68,    '5/23/2019', 48, 10),
(69,  69,    '2/28/2020', 10, 8),
(70,  70,    '4/8/2020', 51, 10),
(71,  71,    '8/28/2019', 85, 20),
(72,  72,    '5/1/2020', 34, 10),
(73,  73,    '12/10/2019', 26, 14),
(74,  74,    '6/26/2019', 78, 15),
(75,  75,    '6/1/2019', 66, 19),
(76,  76,    '10/9/2019', 65, 18),
(77,  77,    '10/27/2019', 90, 16),
(78,  78,    '5/14/2019', 37, 15),
(79,  79,    '3/28/2020', 26, 3),
(80,  80,    '10/28/2019', 12, 8),
(81,  81,    '11/1/2019', 32, 20),
(82,  82,    '5/7/2019', 85, 6),
(83,  83,    '1/23/2020', 5, 0),
(84,  84,    '12/3/2019', 63, 20),
(85,  85,    '12/25/2019', 2, 4),
(86,  86,    '3/26/2020', 38, 19),
(87,  87,    '3/24/2020', 74, 6),
(88,  88,    '4/10/2020', 75, 5),
(89,  89,    '6/6/2019', 44, 1),
(90,  90,    '5/29/2019', 5, 9),
(91,  91,    '9/12/2019', 77, 8),
(92,  92,    '1/4/2020', 23, 20),
(93,  93,    '1/29/2020', 59, 19),
(94,  94,    '11/30/2019', 32, 17),
(95,  95,    '10/9/2019', 96, 16),
(96,  96,    '12/23/2019', 83, 3),
(97,  97,    '3/27/2020', 36, 4),
(98,  98,    '1/24/2020', 14, 9),
(99,  99,    '12/14/2019', 30, 15),
(100, 100,    '5/27/2019', 85, 5),
(101, 101,    '3/23/2020', 63, 6),
(102, 102,    '6/9/2019', 37, 17),
(103, 103,    '10/10/2019', 26, 15),
(104, 104,    '7/9/2019', 97, 20),
(105, 105,    '3/23/2020', 43, 9),
(106, 106,    '6/29/2019', 20, 15),
(107, 107,    '8/1/2019', 57, 7),
(108, 108,    '4/15/2020', 30, 3),
(109, 109,    '3/2/2020', 8, 0),
(110, 110,    '2/5/2020', 72, 19),
(111, 111,    '8/15/2019', 46, 15),
(112, 112,    '1/15/2020', 11, 12),
(113, 113,    '9/13/2019', 70, 18),
(114, 114,    '11/15/2019', 7, 18),
(115, 115,    '7/2/2019', 85, 13),
(116, 116,    '11/8/2019', 66, 15),
(117, 117,    '1/12/2020', 14, 10),
(118, 118,    '7/5/2019', 34, 14),
(119, 119,    '3/26/2020', 37, 4),
(120, 120,    '5/14/2019', 71, 11),
(121, 121,    '6/26/2019', 55, 0),
(122, 122,    '10/28/2019', 46, 11),
(123, 123,    '12/16/2019', 77, 6),
(124, 124,    '9/10/2019', 17, 3),
(125, 125,    '6/21/2019', 68, 4),
(126, 126,    '3/12/2020', 43, 17),
(127, 127,    '2/27/2020', 35, 13),
(128, 128,    '3/2/2020', 88, 3),
(129, 129,    '10/25/2019', 6, 2),
(130, 130,    '10/18/2019', 23, 1),
(131, 131,    '10/20/2019', 26, 11),
(132, 132,    '7/30/2019', 65, 6),
(133, 133,    '6/15/2019', 64, 9),
(134, 134,    '7/23/2019', 37, 1),
(135, 135,    '12/11/2019', 92, 15),
(136, 136,    '1/29/2020', 84, 16),
(137, 137,    '3/17/2020', 91, 19),
(138, 138,    '3/28/2020', 59, 18),
(139, 139,    '3/14/2020', 4, 4),
(140, 140,    '9/10/2019', 99, 9),
(141, 141,    '11/30/2019', 83, 7),
(142, 142,    '1/16/2020', 16, 10),
(143, 143,    '1/17/2020', 58, 19),
(144, 144,    '7/10/2019', 29, 11),
(145, 145,    '5/15/2019', 33, 19),
(146, 146,    '11/4/2019', 64, 9),
(147, 147,    '10/3/2019', 27, 17),
(148, 148,    '12/28/2019', 87, 9),
(149, 149,    '7/21/2019', 64, 7),
(150, 150,    '11/29/2019', 34, 4),
(151, 151,    '7/4/2019', 83, 15),
(152, 152,    '4/15/2020', 70, 6)
SET IDENTITY_INSERT harvestTbl OFF
SELECT * FROM harvestTbl

SET IDENTITY_INSERT actionTbl ON
INSERT INTO actionTbl (actionId, planted, watered, fertilized, depested, noAction) 
VALUES (1, 1, 0, 0, 0, 0),
(2, 1, 1, 1, 0, 0),
(3, 0, 0, 0, 0, 0),
(4, 1, 1, 0, 0, 0),
(5, 0, 1, 0, 0, 0),
(6, 0, 1, 0, 1, 0),
(7, 1, 1, 1, 0, 0),
(8, 1, 1, 1, 1, 0),
(9, 0, 1, 0, 1, 0),
(10, 0, 1, 0, 0, 0),
(11, 0, 0, 0, 0, 0),
(12, 0, 0, 0, 1, 0),
(13, 1, 1, 1, 0, 0),
(14, 1, 0, 1, 0, 0),
(15, 0, 0, 1, 1, 0),
(16, 0, 1, 1, 1, 0),
(17, 1, 0, 1, 1, 0),
(18, 0, 0, 1, 1, 0),
(19, 1, 0, 0, 0, 0),
(20, 1, 1, 0, 1, 0),
(21, 0, 0, 1, 1, 0),
(22, 1, 1, 0, 0, 0),
(23, 1, 0, 0, 1, 0),
(24, 0, 0, 0, 1, 0),
(25, 0, 1, 0, 1, 0),
(26, 0, 1, 0, 1, 0),
(27, 1, 0, 1, 0, 0),
(28, 1, 0, 1, 1, 0),
(29, 0, 0, 0, 0, 0),
(30, 0, 0, 1, 1, 0),
(31, 0, 0, 1, 1, 0),
(32, 1, 0, 1, 1, 0),
(33, 1, 0, 0, 1, 0),
(34, 1, 0, 1, 1, 0),
(35, 1, 1, 1, 1, 0),
(36, 1, 1, 0, 0, 0),
(37, 0, 1, 0, 0, 0),
(38, 0, 1, 1, 0, 0),
(39, 1, 1, 0, 1, 0),
(40, 1, 0, 1, 1, 0),
(41, 0, 0, 1, 1, 0),
(42, 1, 0, 1, 1, 0),
(43, 1, 0, 0, 1, 0),
(44, 0, 0, 0, 0, 0),
(45, 1, 0, 1, 0, 0),
(46, 0, 0, 0, 0, 0),
(47, 0, 0, 0, 1, 0),
(48, 0, 1, 0, 0, 0),
(49, 1, 0, 1, 1, 0),
(50, 0, 0, 1, 0, 0),
(51, 0, 0, 0, 0, 0),
(52, 1, 0, 0, 0, 0),
(53, 0, 0, 0, 0, 0),
(54, 1, 1, 0, 1, 0),
(55, 1, 1, 0, 1, 0),
(56, 0, 0, 0, 0, 0),
(57, 1, 1, 0, 0, 0),
(58, 1, 0, 0, 0, 0),
(59, 1, 1, 1, 1, 0),
(60, 1, 1, 0, 0, 0),
(61, 0, 1, 0, 1, 0),
(62, 1, 1, 1, 1, 0),
(63, 1, 1, 0, 1, 0),
(64, 1, 0, 1, 0, 0),
(65, 0, 1, 0, 0, 0),
(66, 0, 1, 1, 0, 0),
(67, 0, 0, 0, 1, 0),
(68, 0, 0, 1, 0, 0),
(69, 0, 0, 0, 1, 0),
(70, 0, 1, 0, 1, 0),
(71, 1, 1, 0, 1, 0),
(72, 1, 1, 1, 1, 0),
(73, 1, 0, 0, 1, 0),
(74, 0, 1, 0, 0, 0),
(75, 1, 1, 0, 0, 0),
(76, 1, 0, 1, 0, 0),
(77, 0, 0, 1, 0, 0),
(78, 1, 1, 0, 1, 0),
(79, 0, 1, 1, 1, 0),
(80, 1, 0, 0, 1, 0),
(81, 1, 0, 0, 1, 0),
(82, 1, 0, 0, 1, 0),
(83, 0, 1, 0, 1, 0),
(84, 0, 0, 1, 0, 0),
(85, 1, 0, 0, 1, 0),
(86, 0, 1, 1, 0, 0),
(87, 0, 0, 1, 1, 0),
(88, 0, 0, 0, 1, 0),
(89, 0, 1, 1, 0, 0),
(90, 1, 0, 1, 1, 0),
(91, 1, 0, 1, 1, 0),
(92, 0, 0, 1, 0, 0),
(93, 1, 0, 1, 0, 0),
(94, 1, 0, 0, 1, 0),
(95, 0, 0, 1, 1, 0),
(96, 0, 1, 1, 0, 0),
(97, 1, 0, 0, 1, 0),
(98, 0, 1, 0, 0, 0),
(99, 0, 1, 0, 0, 0),
(100, 0, 0, 1, 0, 0),
(101, 1, 1, 0, 1, 0),
(102, 1, 1, 1, 0, 0),
(103, 0, 0, 1, 0, 0),
(104, 0, 1, 0, 0, 0),
(105, 1, 0, 1, 1, 0),
(106, 1, 1, 1, 0, 0),
(107, 0, 1, 0, 1, 0),
(108, 1, 1, 0, 0, 0),
(109, 0, 0, 1, 1, 0),
(110, 1, 0, 0, 0, 0),
(111, 1, 0, 0, 1, 0),
(112, 1, 1, 1, 0, 0),
(113, 1, 0, 1, 1, 0),
(114, 0, 1, 1, 1, 0),
(115, 1, 0, 1, 0, 0),
(116, 0, 1, 1, 1, 0),
(117, 0, 1, 0, 1, 0),
(118, 1, 0, 1, 0, 0),
(119, 0, 0, 0, 1, 0),
(120, 0, 1, 1, 1, 0),
(121, 1, 1, 1, 1, 0),
(122, 0, 1, 0, 1, 0),
(123, 1, 0, 0, 1, 0),
(124, 0, 1, 1, 1, 0),
(125, 0, 0, 0, 0, 0),
(126, 1, 0, 0, 1, 0),
(127, 0, 1, 0, 0, 0),
(128, 0, 1, 0, 1, 0),
(129, 0, 1, 1, 0, 0),
(130, 1, 0, 1, 0, 0),
(131, 1, 1, 1, 1, 0),
(132, 1, 1, 1, 1, 0),
(133, 1, 1, 0, 1, 0),
(134, 1, 0, 1, 0, 0),
(135, 0, 1, 1, 1, 0),
(136, 1, 0, 1, 1, 0),
(137, 0, 0, 0, 0, 0),
(138, 0, 0, 0, 1, 0),
(139, 1, 1, 1, 0, 0),
(140, 0, 1, 0, 0, 0),
(141, 1, 1, 0, 1, 0),
(142, 1, 1, 1, 0, 0),
(143, 0, 0, 1, 1, 0),
(144, 1, 0, 1, 0, 0),
(145, 0, 1, 1, 1, 0),
(146, 0, 0, 0, 1, 0),
(147, 1, 1, 1, 1, 0),
(148, 1, 1, 1, 0, 0),
(149, 0, 1, 0, 0, 0),
(150, 1, 1, 1, 0, 0),
(151, 0, 1, 1, 1, 0),
(152, 1, 1, 0, 0, 0)
SET IDENTITY_INSERT actionTbl OFF
SELECT * FROM actionTbl

SET IDENTITY_INSERT tendedTbl ON
INSERT INTO tendedTbl (tendedId, actionId, plantId, soilCondId, recordedDate, plantCondition) 
VALUES 
(1, 1, 1, 1, '11/21/2019',	'INFESTED'),
(2, 2, 2, 2, '2/8/2020',	'DEHYDRATED'),
(3, 3, 3, 3, '10/1/2019',	'INFESTED'),
(4, 4, 4, 4, '6/10/2019',	 'WILTED'),
(5, 5, 5, 5, '2/20/2020', 'BURNT'),
(6, 6, 6, 6, '4/21/2020', 'WILTED'),
(7, 7, 7, 7, '4/16/2020', 'BURNT'),
(8, 8, 8, 8, '10/13/2019', 'HEALTHY'),
(9, 9, 9, 9, '9/16/2019',  'WILTED'),
(10, 10, 10, 10, '10/17/2019', 'DEHYDRATED'),
(11, 11, 11, 11, '4/28/2020', 'BURNT'),
(12, 12, 12, 12, '11/20/2019', 'INFESTED'),
(13, 13, 13, 13, '12/16/2019', 'DEHYDRATED'),
(14, 14, 14, 14, '4/9/2020', 'INFESTED'),
(15, 15, 15, 15, '1/16/2020', 'DEHYDRATED'),
(16, 16, 16, 16, '6/7/2019', 'DEHYDRATED'),
(17, 17, 17, 17, '7/25/2019', 'BURNT'),
(18, 18, 18, 18, '7/25/2019', 'BURNT'),
(19, 19, 19, 19, '9/2/2019', 'WILTED'),
(20, 20, 20, 20, '7/18/2019', 'HEALTHY'),
(21, 21, 21, 21, '7/30/2019', 'INFESTED'),
(22, 22, 22, 22, '2/27/2020', 'DEHYDRATED'),
(23, 23, 23, 23, '4/24/2020', 'BURNT'),
(24, 24, 24, 24, '1/14/2020', 'WILTED'),
(25, 25, 25, 25, '7/4/2019', 'INFESTED'),
(26, 26, 26, 26, '5/17/2019', 'WILTED'),
(27, 27, 27, 27, '12/24/2019', 'WILTED'),
(28, 28, 28, 28, '4/5/2020', 'WILTED'),
(29, 29, 29, 29, '12/18/2019', 'BURNT'),
(30, 30, 30, 30, '8/24/2019', 'HEALTHY'),
(31, 31, 31, 31, '6/12/2019', 'HEALTHY'),
(32, 32, 32, 32, '4/28/2020', 'BURNT'),
(33, 33, 33, 33, '8/16/2019', 'BURNT'),
(34, 34, 34, 34, '1/31/2020', 'HEALTHY'),
(35, 35, 35, 35, '5/1/2020', 'HEALTHY'),
(36, 36, 36, 36, '3/20/2020', 'WILTED'),
(37, 37, 37, 37, '3/18/2020', 'HEALTHY'),
(38, 38, 38, 38, '9/30/2019', 'HEALTHY'),
(39, 39, 39, 39, '4/6/2020', 'INFESTED'),
(40, 40, 40, 40, '9/23/2019', 'DEHYDRATED'),
(41, 41, 41, 41, '6/26/2019', 'WILTED'),
(42, 42, 42, 42, '10/17/2019', 'INFESTED'),
(43, 43, 43, 43, '12/12/2019', 'INFESTED'),
(44, 44, 44, 44, '5/31/2019', 'DEHYDRATED'),
(45, 45, 45, 45, '8/14/2019', 'BURNT'),
(46, 46, 46, 46, '10/19/2019', 'DEHYDRATED'),
(47, 47, 47, 47, '9/22/2019', 'HEALTHY'),
(48, 48, 48, 48, '10/29/2019', 'BURNT'),
(49, 49, 49, 49, '10/20/2019', 'INFESTED'),
(50, 50, 50, 50, '1/13/2020', 'INFESTED'),
(51, 51, 51, 51, '9/28/2019', 'WILTED'),
(52, 52, 52, 52, '11/17/2019', 'WILTED'),
(53, 53, 53, 53, '5/29/2019', 'HEALTHY'),
(54, 54, 54, 54, '6/17/2019', 'HEALTHY'),
(55, 55, 55, 55, '9/2/2019', 'DEHYDRATED'),
(56, 56, 56, 56, '10/13/2019', 'INFESTED'),
(57, 57, 57, 57, '7/26/2019', 'WILTED'),
(58, 58, 58, 58, '7/26/2019', 'WILTED'),
(59, 59, 59, 59, '5/9/2019', 'HEALTHY'),
(60, 60, 60, 60, '2/12/2020', 'HEALTHY'),
(61, 61, 61, 61, '5/15/2019', 'INFESTED'),
(62, 62, 62, 62, '12/9/2019', 'INFESTED'),
(63, 63, 63, 63, '8/28/2019', 'HEALTHY'),
(64, 64, 64, 64, '4/13/2020', 'INFESTED'),
(65, 65, 65, 65, '2/25/2020', 'DEHYDRATED'),
(66, 66, 66, 66, '6/1/2019', 'INFESTED'),
(67, 67, 67, 67, '7/16/2019', 'WILTED'),
(68, 68, 68, 68, '12/13/2019', 'WILTED'),
(69, 69, 69, 69, '11/15/2019', 'INFESTED'),
(70, 70, 70, 70, '6/13/2019', 'WILTED'),
(71, 71, 71, 71, '3/23/2020', 'INFESTED'),
(72, 72, 72, 72, '10/31/2019', 'HEALTHY'),
(73, 73, 73, 73, '11/27/2019', 'HEALTHY'),
(74, 74, 74, 74, '10/18/2019', 'BURNT'),
(75, 75, 75, 75, '5/21/2019', 'BURNT'),
(76, 76, 76, 76, '1/31/2020', 'HEALTHY'),
(77, 77, 77, 77, '7/27/2019', 'WILTED'),
(78, 78, 78, 78, '12/21/2019', 'DEHYDRATED'),
(79, 79, 79, 79, '6/20/2019', 'WILTED'),
(80, 80, 80, 80, '6/16/2019', 'DEHYDRATED'),
(81, 81, 81, 81, '3/7/2020', 'WILTED'),
(82, 82, 82, 82, '5/4/2020', 'WILTED'),
(83, 83, 83, 83, '1/31/2020', 'WILTED'),
(84, 84, 84, 84, '12/17/2019', 'INFESTED'),
(85, 85, 85, 85, '12/10/2019', 'WILTED'),
(86, 86, 86, 86, '12/6/2019', 'WILTED'),
(87, 87, 87, 87, '10/13/2019', 'BURNT'),
(88, 88, 88, 88, '4/28/2020', 'DEHYDRATED'),
(89, 89, 89, 89, '12/12/2019', 'INFESTED'),
(90, 90, 90, 90, '6/19/2019', 'DEHYDRATED'),
(91, 91, 91, 91, '2/14/2020', 'WILTED'),
(92, 92, 92, 92, '10/14/2019', 'HEALTHY'),
(93, 93, 93, 93, '3/22/2020', 'DEHYDRATED'),
(94, 94, 94, 94, '3/5/2020', 'BURNT'),
(95, 95, 95, 95, '10/2/2019', 'DEHYDRATED'),
(96, 96, 96, 96, '7/16/2019', 'BURNT'),
(97, 97, 97, 97, '5/19/2019', 'DEHYDRATED'),
(98, 98, 98, 98, '6/12/2019', 'DEHYDRATED'),
(99, 99, 99, 99, '1/26/2020', 'DEHYDRATED'),
(100, 100, 100, 100, '2/1/2020', 'INFESTED'),
(101, 101, 101, 101, '11/7/2019', 'DEHYDRATED'),
(102, 102, 102, 102, '10/30/2019', 'DEHYDRATED'),
(103, 103, 103, 103, '7/23/2019', 'DEHYDRATED'),
(104, 104, 104, 104, '4/28/2020', 'INFESTED'),
(105, 105, 105, 105, '1/12/2020', 'INFESTED'),
(106, 106, 106, 106, '3/8/2020', 'BURNT'),
(107, 107, 107, 107, '1/3/2020', 'WILTED'),
(108, 108, 108, 108, '5/11/2019', 'BURNT'),
(109, 109, 109, 109, '12/12/2019', 'WILTED'),
(110, 110, 110, 110, '7/15/2019', 'HEALTHY'),
(111, 111, 111, 111, '10/2/2019', 'BURNT'),
(112, 112, 112, 112, '8/27/2019', 'WILTED'),
(113, 113, 113, 113, '7/22/2019', 'INFESTED'),
(114, 114, 114, 114, '1/19/2020', 'HEALTHY'),
(115, 115, 115, 115, '4/17/2020', 'HEALTHY'),
(116, 116, 116, 116, '12/16/2019', 'DEHYDRATED'),
(117, 117, 117, 117, '8/2/2019', 'WILTED'),
(118, 118, 118, 118, '5/23/2019', 'INFESTED'),
(119, 119, 119, 119, '12/1/2019', 'INFESTED'),
(120, 120, 120, 120, '6/7/2019', 'BURNT'),
(121, 121, 121, 121, '3/16/2020', 'BURNT'),
(122, 122, 122, 122, '5/1/2020', 'WILTED'),
(123, 123, 123, 123, '7/15/2019', 'INFESTED'),
(124, 124, 124, 124, '4/14/2020', 'INFESTED'),
(125, 125, 125, 125, '12/19/2019', 'INFESTED'),
(126, 126, 126, 126, '6/2/2019', 'INFESTED'),
(127, 127, 127, 127, '6/13/2019', 'DEHYDRATED'),
(128, 128, 128, 128, '1/21/2020', 'BURNT'),
(129, 129, 129, 129, '4/6/2020', 'HEALTHY'),
(130, 130, 130, 130, '12/24/2019', 'DEHYDRATED'),
(131, 131, 131, 131, '2/4/2020', 'INFESTED'),
(132, 132, 132, 132, '12/18/2019', 'INFESTED'),
(133, 133, 133, 133, '8/23/2019', 'BURNT'),
(134, 134, 134, 134, '8/19/2019', 'BURNT'),
(135, 135, 135, 135, '4/5/2020', 'DEHYDRATED'),
(136, 136, 136, 136, '10/11/2019', 'INFESTED'),
(137, 137, 137, 137, '6/14/2019', 'WILTED'),
(138, 138, 138, 138, '9/15/2019', 'BURNT'),
(139, 139, 139, 139, '9/20/2019', 'HEALTHY'),
(140, 140, 140, 140, '3/26/2020', 'DEHYDRATED'),
(141, 141, 141, 141, '3/1/2020', 'BURNT'),
(142, 142, 142, 142, '3/18/2020', 'DEHYDRATED'),
(143, 143, 143, 143, '10/9/2019', 'HEALTHY'),
(144, 144, 144, 144, '5/23/2019', 'INFESTED'),
(145, 145, 145, 145, '6/23/2019', 'HEALTHY'),
(146, 146, 146, 146, '5/11/2019', 'HEALTHY'),
(147, 147, 147, 147, '10/12/2019', 'HEALTHY'),
(148, 148, 148, 148, '4/27/2020', 'INFESTED'),
(149, 149, 149, 149, '8/20/2019', 'BURNT'),
(150, 150, 150, 150, '7/16/2019', 'HEALTHY'),
(151, 151, 151, 151, '5/6/2020', 'HEALTHY'),
(152, 152, 152, 152, '12/16/2019', 'HEALTHY')
SET IDENTITY_INSERT tendedTbl OFF
SELECT * FROM tendedTbl 


/************************************************************************************************************  
												TEST PROCEDURES
*************************************************************************************************************/
EXEC spGetSoilListByPh 0.0, 5.0;
EXEC spGetLocByPlantType 'omat';
EXEC spGetPlantConditionByDate '12/8/2019', '12/31/2019'
EXEC spGetWeatherByDate '12/8/2019', '12/31/2019'
EXEC spGetHarvestsByDateRange '12/31/2019', '5/8/2020';
EXEC spGetPlantByTypeName 'Tomato', 1 --Hard Match Test
EXEC spGetPlantByTypeName 'umbe', 0 --Soft Match Test
EXEC spGetPlantBreedByName 'Roma', 1 --Hard Match Test
EXEC spGetPlantBreedByName 'Gold', 0 --Soft Match Test
EXEC spAddUpdateArchive_Weather 0, 65, 2, 33, 5, 2, 'N', '5/8/2020'; -- Add Weather Test
EXEC spAddUpdateArchive_Weather 0, 20, 3, 27, 2, 5, 'N', '5/8/2020'; -- Add Another So we can delete one
EXEC spAddUpdateArchive_Weather 1, 10, 1, 12, 0, 1, 'S', '5/5/2020'; -- Update Weather Test
EXEC spAddUpdateArchive_Weather 1, 10, 1, 12, 0, 1, 'S', '5/5/2020', 1; -- DELETE from Weather Test

/************************************************************************************************************  
												TEST VIEWS
*************************************************************************************************************/
SELECT * FROM vwDepestedList ORDER BY plantID
SELECT * FROM vwFertilizedList ORDER BY plantID
SELECT * FROM vwHarvestDate ORDER BY plantID
SELECT * FROM vwPlantedList ORDER BY plantID
SELECT * FROM vwPlantList ORDER BY plantId
SELECT * FROM vwPlantLocation ORDER BY plantID
SELECT * FROM vwTypeList ORDER BY plantName
SELECT * FROM vwWateredList ORDER BY plantId