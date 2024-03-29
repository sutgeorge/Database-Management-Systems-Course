/**
    Create a stored procedure that inserts data in tables that are in a m:n relationship;
    If one insert fails, all the operations performed by the procedure must be rolled back.
**/

DROP TABLE LogTable;
CREATE TABLE LogTable
    (LogId INT PRIMARY KEY IDENTITY (1,1),
     OperationType VARCHAR(64),
     OperationTable VARCHAR(64),
     Time TIMESTAMP);

CREATE OR ALTER FUNCTION validateArtistNameAndEstablishmentYear(@ArtistName VARCHAR(50), @EstablishmentYear SMALLINT)
RETURNS INT
AS
BEGIN
    IF @ArtistName IS NULL OR @EstablishmentYear IS NULL
    BEGIN
        RETURN 0
    END

    RETURN 1
END
GO


CREATE OR ALTER FUNCTION validateAlbumParameters(@AlbumName VARCHAR(50), @ReleaseDate DATE)
RETURNS INT
AS
BEGIN
    IF @AlbumName IS NULL OR @ReleaseDate IS NULL
    BEGIN
        RETURN 0
    END

    RETURN 1
END
GO


CREATE OR ALTER PROCEDURE addArtist(@ArtistName VARCHAR(50), @EstablishmentYear SMALLINT)
AS
    IF (dbo.validateArtistNameAndEstablishmentYear(@ArtistName, @EstablishmentYear) <> 1)
    BEGIN
        INSERT INTO LogTable (OperationType, OperationTable, Time) VALUES ('INSERT VALIDATION ERROR', 'Artist', CURRENT_TIMESTAMP())
        RAISERROR ('The artist name and establishment year cannot be null.', 6, 1)
        RETURN
    END
    INSERT INTO Artist (Name, EstablishmentYear) VALUES (@ArtistName, @EstablishmentYear)
    INSERT INTO LogTable (OperationType, OperationTable) VALUES ('INSERT', 'Artist')
GO

CREATE OR ALTER PROCEDURE addAlbum(@AlbumName VARCHAR(50), @ReleaseDate DATE, @AlbumArtLink VARCHAR(200))
AS
    IF (dbo.validateAlbumParameters(@AlbumName, @ReleaseDate) <> 1)
    BEGIN
        INSERT INTO LogTable (OperationType, OperationTable) VALUES ('INSERT VALIDATION ERROR', 'Album')
        RAISERROR ('The album name and release date cannot be null.', 6, 1)
        RETURN
    END
    INSERT INTO Album (Name, ReleaseDate, AlbumArtLink) VALUES (@AlbumName, @ReleaseDate, @AlbumArtLink)
    INSERT INTO LogTable (OperationType, OperationTable) VALUES ('INSERT', 'Album')
GO

CREATE OR ALTER PROCEDURE addArtistAlbumAssociation(@ArtistName VARCHAR(50), @AlbumName VARCHAR(50))
AS
    DECLARE @ArtistId INT = (SELECT ArtistId FROM Artist WHERE Name = @ArtistName)
    DECLARE @AlbumId INT = (SELECT AlbumId FROM Album WHERE Name = @AlbumName)

    IF @ArtistId IS NULL
    BEGIN
        PRINT '@ArtistId is null...'
        EXEC addArtist @ArtistName, 1900
        SET @ArtistId = (SELECT ArtistId FROM Artist WHERE Name = @ArtistName)
    END

    IF @AlbumId IS NULL
    BEGIN
        PRINT '@AlbumId is null...'
        DECLARE @CurrentDate DATE = CAST(GETDATE() as DATE)
        EXEC addAlbum @AlbumName, @CurrentDate, ''
        SET @AlbumId = (SELECT AlbumId FROM Album WHERE Name = @AlbumName)
    END

    IF (SELECT COUNT(*) FROM Artists_Albums WHERE ArtistId = @ArtistId AND AlbumId = @AlbumId) > 0
    BEGIN
        INSERT INTO LogTable (OperationType, OperationTable) VALUES ('INSERT VALIDATION ERROR', 'Albums_Artists')
        RAISERROR ('An association between the given artist and album already exists.', 2, 1)
        RETURN
    END

    INSERT INTO Artists_Albums (ArtistId, AlbumId) VALUES (@ArtistId, @AlbumId)
    INSERT INTO LogTable (OperationType, OperationTable) VALUES ('INSERT', 'Artists_Albums')
GO

CREATE OR ALTER PROCEDURE addAssociationInsideATransaction(@ArtistName VARCHAR(50), @AlbumName VARCHAR(50))
AS
    BEGIN TRANSACTION

    BEGIN TRY
        EXEC addArtistAlbumAssociation @ArtistName, @AlbumName
        COMMIT TRANSACTION
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION
        RETURN
    END CATCH
GO

CREATE OR ALTER PROCEDURE failedScenario
AS
    EXEC addAssociationInsideATransaction 'Pink Floyd', 'Dark Side Of The Moon'
GO

CREATE OR ALTER PROCEDURE successfulScenario
AS
    EXEC addAssociationInsideATransaction 'Pink Floyd', 'The Wall'
GO

/**
 DON'T USE IDs AS PARAMETERS!
**/

EXEC failedScenario
EXEC successfulScenario
SELECT * FROM Artists_Albums;
SELECT * FROM Album;


SELECT * FROM LogTable;